"""
COOKIES续期内部接口

功能：
1. 对外提供 WebSocket 服务内部 COOKIES 浏览器续期接口
2. 在 WebSocket 进程中执行浏览器续期
3. 将刷新后的 Cookie 直接写回数据库，仅返回安全摘要
"""
from __future__ import annotations

from hmac import compare_digest
from typing import Any, TypeVar

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from loguru import logger
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from common.core.config import get_internal_service_secret
from common.db.session import async_session_maker
from common.models.xy_account import XYAccount
from common.services.captcha.concurrency import run_browser_task
from common.services.cookie_renew_browser_service import cookie_renew_browser_service
from common.utils.cookie_refresh import (
    build_cookie_string_from_browser_cookies,
    clear_cookie_refresh_snapshot,
    get_cookie_refresh_snapshot,
    normalize_browser_cookie_snapshot,
    set_cookie_refresh_snapshot,
)
from common.utils.time_utils import get_beijing_now_naive
from app.services.xianyu.cookies_refresh_service import cookies_refresh_service


def verify_internal_service_secret(
    x_internal_service_secret: str | None = Header(
        default=None,
        alias="X-Internal-Service-Secret",
    ),
) -> None:
    """校验内部服务间通信密钥。"""
    expected_secret = get_internal_service_secret()
    provided_secret_bytes = (x_internal_service_secret or "").encode("utf-8")
    expected_secret_bytes = expected_secret.encode("utf-8")
    if not compare_digest(provided_secret_bytes, expected_secret_bytes):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid internal service secret",
        )


router = APIRouter(
    prefix="/internal",
    tags=["internal"],
    dependencies=[Depends(verify_internal_service_secret)],
)


class CookiesRefreshRequest(BaseModel):
    """COOKIES续期请求。"""

    model_config = ConfigDict(extra="forbid")

    account_id: str
    owner_id: int


class BrowserRenewRequest(BaseModel):
    """浏览器续期委托请求（由 scheduler / backend-web 调用）。"""

    model_config = ConfigDict(extra="forbid")

    account_id: str
    owner_id: int


_RequestModelT = TypeVar("_RequestModelT", bound=BaseModel)


async def _parse_request_body(
    raw_request: Request,
    model_type: type[_RequestModelT],
) -> _RequestModelT:
    """手动校验请求并返回固定错误，避免 Pydantic 422 回显敏感输入。"""
    try:
        payload = await raw_request.json()
        return model_type.model_validate(payload)
    except Exception:
        raise HTTPException(
            status_code=422,
            detail="Invalid request body",
        ) from None


async def _get_owned_account(
    session: AsyncSession,
    account_id: str,
    owner_id: int,
    *,
    for_update: bool = False,
) -> XYAccount | None:
    """严格按账号 ID 与数据库归属查询，不做单账号 ID 回退。"""
    statement = select(XYAccount).where(
        XYAccount.account_id == account_id,
        XYAccount.owner_id == owner_id,
    )
    if for_update:
        statement = statement.with_for_update()
    result = await session.execute(statement)
    return result.scalar_one_or_none()


def _account_not_found() -> HTTPException:
    """对账号不存在和归属不匹配返回完全一致的错误。"""
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="账号不存在或归属不匹配",
    )


def _account_state_changed() -> HTTPException:
    """浏览器执行期间账号 Cookie 已变化时拒绝覆盖较新的数据库状态。"""
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail="Account state changed; retry later",
    )


def _get_changed_cookie_labels(
    old_snapshot: list[dict[str, Any]],
    new_snapshot: list[dict[str, Any]],
) -> list[str]:
    """仅返回变化 Cookie 的名称/域摘要，不包含 Cookie 值。"""
    def record_key(cookie: dict[str, Any]) -> str:
        return "|".join(
            [
                str(cookie.get("name") or ""),
                str(cookie.get("domain") or ""),
                str(cookie.get("path") or "/"),
            ]
        )

    old_map = {record_key(cookie): cookie for cookie in old_snapshot}
    new_map = {record_key(cookie): cookie for cookie in new_snapshot}
    changed_labels: list[str] = []
    for key in sorted(set(old_map) | set(new_map)):
        if old_map.get(key) == new_map.get(key):
            continue
        cookie = new_map.get(key) or old_map.get(key) or {}
        name = str(cookie.get("name") or "").strip()
        domain = str(cookie.get("domain") or "").strip()
        path = str(cookie.get("path") or "/").strip() or "/"
        if name:
            changed_labels.append(f"{name}@{domain}{path}" if domain else name)
    return changed_labels


@router.post(
    "/cookies/browser-renew",
    openapi_extra={
        "requestBody": {
            "required": True,
            "content": {
                "application/json": {
                    "schema": BrowserRenewRequest.model_json_schema(),
                }
            },
        }
    },
)
async def browser_renew(raw_request: Request) -> dict[str, Any]:
    """在 WebSocket 进程内执行浏览器续期（复用持久化目录与账号级互斥锁）。

    供 scheduler / backend-web 通过 HTTP 委托调用，保证所有浏览器续期都收敛到
    WebSocket 进程，与滑块验证同进程串行执行，避免跨进程并发占用同一持久化目录。
    """
    request = await _parse_request_body(raw_request, BrowserRenewRequest)
    try:
        async with async_session_maker() as session:
            account = await _get_owned_account(
                session,
                request.account_id,
                request.owner_id,
            )

        if not account:
            raise _account_not_found()

        logger.info(f"【内部API】收到账号 {account.account_id} 的浏览器续期委托请求")

        # renew_local 为同步阻塞执行（内部含等待槽位/账号锁 + 浏览器操作），
        # 走浏览器任务专用线程池，避免占用 asyncio 默认线程池拖垮 aiohttp 网络请求
        result = await run_browser_task(
            cookie_renew_browser_service.renew_local,
            account.cookie or "",
            account.account_id,
        )

        if result.success and not result.new_cookies_str:
            return {
                "success": False,
                "code": 200,
                "message": "浏览器续期未生成有效 Cookie",
                "data": {
                    "has_quick_enter": result.has_quick_enter,
                    "updated_cookie_count": 0,
                    "updated_cookie_names": [],
                },
            }

        if result.success:
            async with async_session_maker() as session:
                persisted_account = await _get_owned_account(
                    session,
                    request.account_id,
                    request.owner_id,
                    for_update=True,
                )
                if not persisted_account:
                    raise _account_not_found()
                if persisted_account.cookie != account.cookie:
                    raise _account_state_changed()
                persisted_account.cookie = result.new_cookies_str
                persisted_account.metadata_json = clear_cookie_refresh_snapshot(
                    persisted_account.metadata_json
                )
                persisted_account.last_refresh_at = get_beijing_now_naive()
                session.add(persisted_account)
                await session.commit()

        return {
            "success": result.success,
            "code": 200,
            "message": "浏览器续期成功" if result.success else "浏览器续期失败",
            "data": {
                "has_quick_enter": result.has_quick_enter,
                "updated_cookie_count": len(result.updated_cookie_names),
                "updated_cookie_names": result.updated_cookie_names,
            },
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "【内部API】浏览器续期委托异常 "
            f"({type(exc).__name__})"
        )
        return {
            "success": False,
            "code": 500,
            "message": "浏览器续期失败",
            "data": {
                "has_quick_enter": False,
                "updated_cookie_count": 0,
                "updated_cookie_names": [],
            },
        }


@router.post(
    "/cookies/refresh",
    openapi_extra={
        "requestBody": {
            "required": True,
            "content": {
                "application/json": {
                    "schema": CookiesRefreshRequest.model_json_schema(),
                }
            },
        }
    },
)
async def refresh_cookies(raw_request: Request) -> dict[str, Any]:
    """执行账号 COOKIES 浏览器续期。"""
    request = await _parse_request_body(raw_request, CookiesRefreshRequest)
    try:
        async with async_session_maker() as session:
            account = await _get_owned_account(
                session,
                request.account_id,
                request.owner_id,
            )

        if not account:
            raise _account_not_found()

        logger.info(f"【内部API】收到账号 {account.account_id} 的 COOKIES续期请求")

        old_cookie_snapshot = get_cookie_refresh_snapshot(account.metadata_json)

        browser_result = await cookies_refresh_service.refresh_account_cookies(
            account_id=account.account_id,
            cookie=account.cookie or "",
            metadata_json=account.metadata_json,
        )

        if not browser_result.success:
            logger.warning(f"【内部API】账号 {account.account_id} COOKIES续期接口执行失败")
            return {
                "success": False,
                "code": 200,
                "message": "COOKIES续期失败",
                "data": {
                    "account_id": account.account_id,
                    "updated_cookie_count": 0,
                    "updated_cookie_names": [],
                },
            }

        new_cookie_snapshot = normalize_browser_cookie_snapshot(browser_result.cookies)
        new_cookie_string = build_cookie_string_from_browser_cookies(new_cookie_snapshot)
        if not new_cookie_string:
            return {
                "success": False,
                "code": 200,
                "message": "浏览器续期未生成有效 Cookie",
                "data": {
                    "account_id": account.account_id,
                    "updated_cookie_count": 0,
                    "updated_cookie_names": [],
                },
            }

        updated_cookie_names = _get_changed_cookie_labels(
            old_cookie_snapshot,
            new_cookie_snapshot,
        )
        async with async_session_maker() as session:
            persisted_account = await _get_owned_account(
                session,
                request.account_id,
                request.owner_id,
                for_update=True,
            )
            if not persisted_account:
                raise _account_not_found()
            if persisted_account.cookie != account.cookie:
                raise _account_state_changed()
            persisted_account.cookie = new_cookie_string
            persisted_account.metadata_json = set_cookie_refresh_snapshot(
                persisted_account.metadata_json,
                new_cookie_snapshot,
            )
            persisted_account.last_refresh_at = get_beijing_now_naive()
            session.add(persisted_account)
            await session.commit()

        return {
            "success": True,
            "code": 200,
            "message": f"COOKIES续期成功，更新 {len(updated_cookie_names)} 个字段",
            "data": {
                "account_id": account.account_id,
                "updated_cookie_count": len(updated_cookie_names),
                "updated_cookie_names": updated_cookie_names,
            },
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "【内部API】COOKIES续期异常 "
            f"({type(exc).__name__})"
        )
        return {
            "success": False,
            "code": 500,
            "message": "COOKIES续期失败",
            "data": None,
        }
