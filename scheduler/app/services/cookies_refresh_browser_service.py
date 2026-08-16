"""
COOKIES续期浏览器服务

功能：
1. 调用 WebSocket 服务内部接口执行 COOKIES 浏览器续期
2. 统一由 WebSocket 服务承担浏览器执行职责
3. 仅返回 Cookie 更新摘要，完整 Cookie 由 WebSocket 服务直接写入数据库
"""
from __future__ import annotations

from dataclasses import dataclass, field

from loguru import logger

from common.core.config import get_internal_service_secret
from common.models.xy_account import XYAccount
from app.core.config import get_settings
from app.core.http_client import get_http_client


@dataclass(slots=True)
class CookiesRefreshBrowserResult:
    """浏览器续期执行结果。"""

    success: bool
    message: str
    updated_cookie_count: int = 0
    updated_cookie_names: list[str] = field(default_factory=list)


class CookiesRefreshBrowserService:
    """COOKIES续期浏览器服务。"""

    async def refresh_account_cookies(self, account: XYAccount) -> CookiesRefreshBrowserResult:
        """执行单个账号的浏览器COOKIES续期。"""
        settings = get_settings()
        http_client = get_http_client()
        logger.info(f"【COOKIES续期】账号 {account.account_id} 开始调用 websocket COOKIES续期接口")
        try:
            response = await http_client.post(
                f"{settings.websocket_service_url}/internal/cookies/refresh",
                json={
                    "account_id": account.account_id,
                    "owner_id": account.owner_id,
                },
                headers={
                    "X-Internal-Service-Secret": get_internal_service_secret(),
                },
            )
        except Exception as exc:
            logger.error(f"【COOKIES续期】账号 {account.account_id} 调用 websocket COOKIES续期接口失败: {exc}")
            raise

        if not isinstance(response, dict):
            logger.error(
                f"【COOKIES续期】账号 {account.account_id} "
                "调用 websocket COOKIES续期接口失败: 返回格式异常"
            )
            return CookiesRefreshBrowserResult(
                success=False,
                message="COOKIES续期接口返回格式异常",
            )

        data = response.get("data") if isinstance(response.get("data"), dict) else {}
        raw_updated_cookie_names = data.get("updated_cookie_names")
        updated_cookie_names = (
            [str(name) for name in raw_updated_cookie_names if isinstance(name, str)]
            if isinstance(raw_updated_cookie_names, list)
            else []
        )
        raw_updated_cookie_count = data.get("updated_cookie_count")
        updated_cookie_count = (
            raw_updated_cookie_count
            if isinstance(raw_updated_cookie_count, int)
            and not isinstance(raw_updated_cookie_count, bool)
            and raw_updated_cookie_count >= 0
            else len(updated_cookie_names)
        )
        success = bool(response.get("success", False))
        message = str(response.get("message") or "COOKIES续期接口未返回消息")
        if not success:
            logger.warning(f"【COOKIES续期】账号 {account.account_id} 调用 websocket COOKIES续期接口失败: {message}")
        return CookiesRefreshBrowserResult(
            success=success,
            message=message,
            updated_cookie_count=updated_cookie_count,
            updated_cookie_names=updated_cookie_names,
        )


cookies_refresh_browser_service = CookiesRefreshBrowserService()
