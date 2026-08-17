# 闲鱼自动回复系统

基于 FastAPI + React + MySQL + Redis + Playwright 的闲鱼多账号自动化系统。

主系统负责账号管理、消息收发、自动回复、自动发货、商品发布与后台管理；`promotion` 子项目负责返佣账号、选品规则、素材库、发布规则、删除规则和相关修复任务。

## 🔴 说明

> **🔴 诚邀各位开发者提交pr，完善系统**
>
> **🔴 承接各类项目定制，各类项目均可，有需要可联系，另外我菜，不一定都会**

## 🔴 最新源码地址(建议转存)

> 🔴 我用夸克网盘给你分享了「自动发货」，点击链接或复制整段内容，打开「夸克网盘APP」即可获取。
> 
> 🔴 /~79313YhCQU~:/
> 
> 🔴 **链接：https://pan.quark.cn/s/af567356cba7**

## 交流群

| 微信群 | QQ群 | 微信公众号 | Telegram | 赞赏支持 |
|:---:|:---:|:---:|:---:|:---:|
| ![微信群](https://xy.zhinianboke.com/static/qrcode/wechat-group.jpg) | ![QQ群](https://xy.zhinianboke.com/static/qrcode/qq-group.jpg) | ![微信公众号](https://xy.zhinianboke.com/static/qrcode/wechat-official-group.jpg) | ![Telegram](https://xy.zhinianboke.com/static/qrcode/telegram-group.png) | ![赞赏支持](https://xy.zhinianboke.com/static/qrcode/reward-group.png) |
| 扫码加入微信交流群 | 扫码加入QQ交流群 | 关注公众号发送"最新源码"获取最新代码 | 扫码加入Telegram群 | 如果觉得好用，请作者喝杯咖啡 |

如群二维码过期，请关注公众号获取最新群链接。

---

## 功能概览

### 主系统

| 模块 | 说明 |
|------|------|
| 多账号管理 | 支持多个闲鱼账号登录、状态切换、Cookie 维护与登录续期 |
| 自动回复 | 支持文本关键词、图片关键词、默认回复、商品专属回复 |
| AI 回复 | 支持大模型上下文对话与智能回复 |
| 自动发货 | 支持卡券、虚拟商品、自动补发、发送结果记录 |
| 在线聊天 | 支持会话列表、消息收发、聊天联动 |
| 商品发布 | 支持素材库、地址库、单品发布、批量发布、发布日志 |
| 订单与评价 | 订单拉取、自动评价、求小红花、状态跟踪 |
| 商品采集与分销 | Goofish 采集、货源管理、对接记录、结算链路 |
| 通知与风控 | 支持消息通知、风控日志、系统反馈与公告管理 |

### 返佣子系统

| 模块 | 说明 |
|------|------|
| 返佣账号 | 返佣账号登录、状态管理、Cookie 维护 |
| 选品规则 | 按规则抓取候选商品并自动写入素材库 |
| 素材库 | 管理标题、图片、详情、淘口令、短链、库存、发布状态 |
| 发布规则 | 定时发布返佣商品，复用公共发布能力 |
| 删除规则 | 定时删除已发布商品 |
| 补偿任务 | 已发布商品 ID 回写、短链修复、卡券补偿等 |

## 技术栈

### 后端与自动化

| 技术 | 说明 |
|------|------|
| FastAPI | 主系统与返佣后端 API 服务 |
| SQLAlchemy 2.0 | ORM 与数据库访问 |
| MySQL 8.0 | 主数据存储 |
| Redis 7 | 缓存、会话与任务辅助 |
| Playwright | 登录、Cookie 刷新、发布等浏览器自动化 |
| APScheduler | 定时任务调度 |
| Loguru | 日志管理 |

### 前端

| 技术 | 说明 |
|------|------|
| React 18 + TypeScript | 主系统与返佣前端 |
| Vite | 开发与构建 |
| TailwindCSS | 主系统 UI 样式 |
| Zustand | 状态管理 |
| Lucide React | 图标体系 |

### 部署

| 技术 | 说明 |
|------|------|
| Docker / Docker Compose | 容器化部署 |
| Nginx | 前端静态资源与反向代理 |

## 系统要求

### 开发环境

- Python 3.11+
- Node.js 18+
- MySQL 8.0+
- Redis 6+
- Chromium / Chrome（Playwright 相关功能）

### 生产环境

- Docker 20.10+
- Docker Compose 2.0+
- 最低 2 核 CPU / 4GB 内存
- 推荐 4 核 CPU / 8GB 内存

## 项目结构

```text
xianyu-auto-reply/
├── backend-web/          # 主 Web API 服务（端口 8089）
├── websocket/            # 闲鱼连接与消息处理服务（端口 8090）
├── scheduler/            # 定时任务服务（端口 8091）
├── common/               # 主系统与返佣系统共享模块
├── frontend/             # 主系统前端（端口 9000）
├── launcher/             # Windows 桌面启动器（Nuitka 打包为 EXE）
├── promotion/
│   ├── backend/          # 返佣后端（端口 8092）
│   └── frontend/         # 返佣前端（端口 9001）
├── scripts/              # CI/CD 与工具脚本
├── docker/frontend/      # 前端 Dockerfile 与 Nginx 配置
├── docker-compose.yml    # 本地源码构建编排
├── deploy.sh             # 一键部署脚本（自动生成远程镜像版 compose）
├── deploy_remote.sh      # 远程 MySQL/Redis 一键部署脚本（自动生成 docker-compose.remote.yml）
├── update.sh             # 一键更新脚本（拉取最新远程镜像）
├── build.sh              # 本地源码全量构建脚本
├── build_frontend.sh     # 单独构建并重启 Frontend
├── build_backend_web.sh  # 单独构建并重启 Backend-Web
├── build_websocket.sh    # 单独构建并重启 WebSocket
├── build_scheduler.sh    # 单独构建并重启 Scheduler
├── EXE打包构建.bat       # Windows 桌面启动器打包脚本
├── 离线依赖打包.bat      # Windows 离线依赖打包脚本
└── README.md
```

### 服务职责

| 服务 | 默认端口 | 说明 |
|------|----------|------|
| `frontend` | 9000 | 主系统前端 |
| `backend-web` | 8089 | 主系统 API 网关、业务接口 |
| `websocket` | 8090 | 闲鱼 WebSocket、消息收发、登录与订单联动 |
| `scheduler` | 8091 | 定时任务执行器 |
| `promotion/backend` | 8092 | 返佣后端 API |
| `promotion/frontend` | 9001 | 返佣前端 |

### 架构说明

- 主系统采用多服务拆分：
  - `frontend` 负责界面与交互
  - `backend-web` 负责大部分业务 API
  - `websocket` 负责闲鱼实时连接、扫码登录、消息处理
  - `scheduler` 负责自动发货、评价、订单拉取、Cookie 刷新等定时任务
  - `common` 提供模型、数据库、自检、公共服务与工具
- 返佣子系统位于 `promotion/` 目录，前后端独立，当前不在根目录 Docker Compose 编排内
- 主系统三个后端服务都提供 `/health` 健康检查接口
- Docker 依赖链：mysql/redis → backend-web → websocket → scheduler；frontend → backend-web

## 快速开始

### 方式一：服务器一键部署（推荐）

服务器已安装 Docker 与 Docker Compose 后，直接执行一键部署脚本即可：

```bash
curl -fsSL https://xy-update.zhinianboke.com/deploy.sh | sed 's/\r$//' | bash
```

该脚本会自动完成部署所需的配置生成、镜像拉取、旧容器清理与服务启动。
当 `.env` 缺少 `INTERNAL_SERVICE_SECRET` 时，脚本会生成高强度随机值并持久化，后续更新会继续复用。
Docker 部署中的 WebSocket 8090 端口仅供容器网络内部访问，不发布到宿主机。

更新版本，直接执行一键更新脚本即可：

```bash
curl -fsSL https://xy-update.zhinianboke.com/update.sh | sed 's/\r$//' | bash
```

### 方式二：克隆仓库部署

```bash
git clone https://github.com/zhinianboke/xianyu-auto-reply.git
cd xianyu-auto-reply
bash deploy.sh
```

- 首次运行会自动生成 `.env` 配置文件和 `docker-compose.deploy.yml`
- 首次运行会自动生成并保存内部服务通信密钥，无需额外手工配置
- 从阿里云镜像仓库拉取预构建镜像并启动
- 如果检测到加密版容器会自动清理（保留数据卷）
- 部署完成后默认访问地址：
  - 前端：`http://服务器IP:9000`
  - API 文档：`http://服务器IP:8089/docs`
  - 默认账号：`admin` / `admin123`

后续更新：

```bash
bash update.sh
```

### 方式三：使用远程 MySQL / Redis 部署

当 MySQL 和 Redis 由外部（如云数据库 RDS、独立服务器或已有实例）提供时，可使用 `deploy_remote.sh`。
该脚本**不内置 mysql/redis 容器**，仅拉取并启动 4 个应用服务（frontend / backend-web / websocket / scheduler），
数据库连接信息通过 `.env.remote` 配置。与方式一相同，直接远程拉取脚本执行即可：

```bash
# 1) 首次运行：自动生成 .env.remote 后退出，提示填写远程连接信息
curl -fsSL https://xy-update.zhinianboke.com/deploy_remote.sh | sed 's/\r$//' | bash

# 2) 编辑 .env.remote，填写真实的远程地址（勿填 localhost）
#    MYSQL_HOST / REDIS_HOST 等
vim .env.remote

# 3) 再次运行：校验配置 → 自动生成 docker-compose.remote.yml → 拉取镜像 → 启动
curl -fsSL https://xy-update.zhinianboke.com/deploy_remote.sh | sed 's/\r$//' | bash
```

> 已克隆仓库的也可改用本地脚本：`bash deploy_remote.sh`（首次生成配置后退出，填好 `.env.remote` 再次执行）。

- 首次运行自动生成 `.env.remote`，每次运行自动生成 `docker-compose.remote.yml`，均不影响根目录原有的 `.env` / `docker-compose.yml` / `docker-compose.deploy.yml`
- 容器名与主套保持一致（`xianyu-backend-web` / `xianyu-websocket` / `xianyu-scheduler` / `xianyu-frontend`），与方式二/方式四属于同一套部署，二者只需选其一，不要同时启动
- 远程 MySQL 需提前创建好数据库（默认 `xianyu_data`）并授权部署机 IP 远程访问，应用启动时会自动建表与补齐字段
- 若远程库/缓存就在宿主机上，请使用 `host.docker.internal` 或宿主机内网 IP，**不要填 `localhost` / `127.0.0.1`**

### 方式四：本地源码 Docker 构建

```bash
bash build.sh rebuild
```

常用命令：

| 命令 | 说明 |
|------|------|
| `bash build.sh rebuild` | 删除旧容器与镜像，重新构建并启动 |
| `bash build.sh start` | 启动服务 |
| `bash build.sh stop` | 停止服务 |
| `bash build.sh restart` | 重启服务 |
| `bash build.sh logs` | 查看实时日志 |
| `bash build.sh status` | 查看服务状态 |

单独重建某个服务（不影响其他服务）：

```bash
bash build_frontend.sh      # 重建前端
bash build_backend_web.sh   # 重建 Backend-Web
bash build_websocket.sh     # 重建 WebSocket
bash build_scheduler.sh     # 重建 Scheduler
```

### 方式五：源码本地开发

#### 1. 准备基础服务

可以使用本机 MySQL / Redis，也可以仅用 Docker 启动基础设施：

```bash
docker compose up -d mysql redis
```

#### 2. 创建服务配置

主系统常用 `.env` 配置示例：

```env
ENVIRONMENT=development
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=root
MYSQL_DATABASE=xianyu_data
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0
CORS_ORIGINS=*
# 三个服务必须使用相同值，可用 openssl rand -hex 32 生成
INTERNAL_SERVICE_SECRET=
BACKEND_WEB_PORT=8089
WEBSOCKET_PORT=8090
SCHEDULER_PORT=8091
WEBSOCKET_SERVICE_URL=http://127.0.0.1:8090
SCHEDULER_SERVICE_URL=http://127.0.0.1:8091
BACKEND_WEB_SERVICE_URL=http://127.0.0.1:8089
STATIC_DIR=static
TZ=Asia/Shanghai
```

#### 3. 启动主系统后端

```bash
# Backend-Web 服务
cd backend-web
python -m venv .venv
# Windows: .venv\Scripts\activate
# Linux/macOS: source .venv/bin/activate
pip install -e .
python -m playwright install chromium
python -m patchright install chromium
python main.py
```

```bash
# WebSocket 服务
cd websocket
python -m venv .venv
# Windows: .venv\Scripts\activate
# Linux/macOS: source .venv/bin/activate
pip install -e .
python -m playwright install chromium
python -m patchright install chromium
python main.py
```

```bash
# Scheduler 服务
cd scheduler
python -m venv .venv
# Windows: .venv\Scripts\activate
# Linux/macOS: source .venv/bin/activate
pip install -e .
python -m playwright install chromium
python main.py
```

#### 4. 启动前端

```bash
cd frontend
npm install
npm run dev
```

#### 5. 启动返佣子系统

```bash
# 返佣后端
cd promotion/backend
pip install -e .
python main.py

# 返佣前端
cd promotion/frontend
npm install
npm run dev
```

## 配置说明

### 关键环境变量

| 变量 | 说明 |
|------|------|
| `MYSQL_HOST` / `MYSQL_PORT` / `MYSQL_USER` / `MYSQL_PASSWORD` / `MYSQL_DATABASE` | MySQL 连接 |
| `REDIS_HOST` / `REDIS_PORT` / `REDIS_PASSWORD` / `REDIS_DB` | Redis 连接 |
| `JWT_SECRET_KEY` | JWT 密钥，由数据库统一托管（首次启动自动生成并持久化），无需手动配置 |
| `INTERNAL_SERVICE_SECRET` | backend-web、scheduler、websocket 共用的内部接口密钥；一键部署脚本会自动生成并保存 |
| `BACKEND_WEB_PORT` / `WEBSOCKET_PORT` / `SCHEDULER_PORT` | 各服务端口 |
| `WEBSOCKET_SERVICE_URL` / `SCHEDULER_SERVICE_URL` / `BACKEND_WEB_SERVICE_URL` | 服务间调用地址 |
| `BACKEND_WEB_PUBLIC_URL` | 对外访问地址，用于生成文件 URL |
| `CORS_ORIGINS` | CORS 白名单 |
| `BROWSER_HEADLESS` | Playwright 是否无头运行 |

### 数据库与初始化

- 主系统启动时自动建表、自检、缺失字段补齐、默认数据初始化
- 默认管理员：`admin` / `admin123`
- 返佣系统启动时执行独立的数据库自检
- 返佣系统表统一使用 `fy_` 前缀
- 不依赖外键约束，关系由代码维护
- 所有时间统一使用北京时间（`Asia/Shanghai`）

### 统一响应格式

后端采用统一响应包装，业务异常也返回 HTTP 200：

```json
{
  "success": true,
  "code": 200,
  "message": "操作成功",
  "data": {}
}
```

## 构建脚本速查

| 脚本 | 平台 | 作用 |
|------|------|------|
| `deploy.sh` | Linux | 生成远程镜像版 compose 并拉取镜像启动（首次部署） |
| `deploy_remote.sh` | Linux | 使用远程 MySQL/Redis 部署，生成 `docker-compose.remote.yml` 与 `.env.remote` 并启动应用服务 |
| `update.sh` | Linux | 拉取最新远程镜像并重建应用容器（后续更新） |
| `build.sh` | Linux | 从源码全量构建所有 Docker 镜像并启动 |
| `build_frontend.sh` | Linux | 单独重建并重启 Frontend 服务 |
| `build_backend_web.sh` | Linux | 单独重建并重启 Backend-Web 服务 |
| `build_websocket.sh` | Linux | 单独重建并重启 WebSocket 服务 |
| `build_scheduler.sh` | Linux | 单独重建并重启 Scheduler 服务 |
| `EXE打包构建.bat` | Windows | 使用 Nuitka 打包桌面启动器 EXE |
| `离线依赖打包.bat` | Windows | 打包所有 Python 依赖供离线安装 |
| `scripts/Pipeline脚本-xianyu-auto-reply.groovy` | Jenkins | CI/CD 流水线，构建多架构镜像并推送到阿里云 ACR |

## 安全说明

- **JWT 认证**：主系统与返佣系统都使用 JWT 做登录态控制
- **密码存储**：密码使用哈希方式保存
- **SQL 注入防护**：数据库访问使用参数化查询
- **XSS 防护**：前端输入与展示做好校验与转义
- **CORS 控制**：生产环境应限制到明确域名

### 生产环境建议

1. 立即修改默认管理员密码
2. JWT 密钥由数据库统一托管，首次启动自动生成强随机密钥（无需手动设置）
3. 设置正确的 `BACKEND_WEB_PUBLIC_URL` 与反向代理地址
4. 为外网入口配置 HTTPS
5. 定期备份 MySQL 与静态资源目录
6. 确保 Playwright 浏览器已正确安装

## 常见问题

### 根目录 Docker Compose 没有启动返佣系统？

当前 `docker-compose.yml` 只覆盖主系统。返佣系统需要单独启动。

### 登录或发布时报浏览器缺失？

Backend-Web 和 WebSocket 需要在对应 Python 环境依次执行：
`python -m playwright install chromium`、`python -m patchright install chromium`。
Docker 环境依赖各服务 Dockerfile 内已安装的浏览器。

### Docker 部署端口冲突？

修改根目录 `.env` 中的端口配置后重新部署。

### 执行脚本报 `/bin/bash^M: 坏的解释器`？

脚本文件包含 Windows 换行符（CRLF），Linux 无法识别。解决方法：

```bash
# 方法一：用 sed 去除 \r 后执行
sed -i 's/\r$//' deploy.sh
bash deploy.sh

# 方法二：通过管道执行（推荐远程脚本使用）
curl -fsSL https://xy-update.zhinianboke.com/deploy.sh | sed 's/\r$//' | bash
```

## 许可证

本项目采用 [GNU Affero General Public License v3.0 (AGPL-3.0)](LICENSE) 开源协议。

**⚠️ 禁止商业用途：本项目仅供学习研究使用，严禁任何形式的商业用途。**

## 免责声明

本项目仅供技术学习和研究使用，使用者需自行承担使用风险。请遵守相关平台的使用条款和法律法规。

- 本项目不对使用本系统造成的任何后果负责
- 请勿用于违反闲鱼平台规则的行为
- 请勿用于商业用途
- 使用本系统可能存在账号风险，请谨慎使用

## 🧸 特别鸣谢

本项目参考了以下开源项目：

- **[XianYuApis](https://github.com/cv-cat/XianYuApis)** - 提供了闲鱼API接口的技术参考
- **[XianyuAutoAgent](https://github.com/shaxiu/XianyuAutoAgent)** - 提供了自动化处理的实现思路
- **[myfish](https://github.com/Kaguya233qwq/myfish)** - 提供了扫码登录的实现思路


感谢这些优秀的开源项目为本项目的开发提供了宝贵的参考和启发！


## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=zhinianboke/xianyu-auto-reply&type=Date)](https://www.star-history.com/#zhinianboke/xianyu-auto-reply&Date)

## 本地灾难备份与恢复（第一版）

这一版备份工具用于现有的单机 Docker Compose 部署，不修改 `docker-compose.yml`，也不改变应用的正常启动方式。脚本只适用于 Linux 云服务器；Windows 开发机可做语法检查，但不要直接执行实际备份或恢复。

### 备份范围

每个完整备份目录包含：

- MySQL 的 `mysqldump` 逻辑备份（gzip 压缩）。
- 项目根目录 `.env`。
- Docker 卷 `static-files`，包含用户上传文件等静态数据。
- Docker 卷 `browser_data`，包含浏览器会话数据。
- `SHA256SUMS` 校验文件和 `COMPLETE` 完成标记。

默认备份根目录是 `/var/backups/xianyu-auto-reply`，完整备份目录的格式为：

```text
/var/backups/xianyu-auto-reply/
└── xianyu-auto-reply_backup_YYYYMMDD_HHMMSS/
```

只会清理超过 7 天、名称和项目标记均通过严格校验的完整备份。未完成备份不会被当作可恢复备份。

第一版不备份 Redis、日志卷或应用自身的 `backup-files` 卷，也不包含远程 rsync/scp、远端保留策略、自动回滚或 age/GPG 加密。Redis 不是权威业务数据库，恢复脚本不会读取、覆盖或删除 `redis_data`；全新服务器由 Compose 创建新的 Redis 数据，已有部署则保留其现有 Redis 卷。

### 配置

在项目根目录执行：

```bash
cp backup.env.example backup.env
chmod 600 backup.env
```

根据服务器环境编辑 `backup.env`。该文件只保存备份工具配置，不应保存数据库密码；数据库连接参数仍由根目录 `.env` 和 MySQL 容器环境提供。真实 `backup.env` 已被 Git 忽略，不要提交它。

可配置项如下；相对路径会以项目根目录为基准解析：

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `LOCAL_BACKUP_DIR` | `/var/backups/xianyu-auto-reply` | 本地备份根目录 |
| `LOCAL_RETENTION_DAYS` | `7` | 完整备份保留天数 |
| `COMPOSE_PROJECT_NAME` | `xianyu-auto-reply` | 第一版固定项目名，不应修改 |
| `COMPOSE_FILE` | `./docker-compose.yml` | 第一版固定使用根目录 Compose 文件，不应改为其他文件 |
| `COMPOSE_ENV_FILE` | `./.env` | 第一版固定备份和恢复根目录 `.env`，不应改为其他文件 |
| `BACKUP_QUIESCE_SERVICES` | `true` | 备份时短暂停止写入服务以获得一致文件快照 |

默认目录位于 `/var/backups`。运行脚本的 Linux 用户必须能够创建并写入该目录；也可以先由管理员创建目录并把所有权授予执行备份的专用用户：

```bash
sudo install -d -m 700 -o "$(id -un)" -g "$(id -gn)" \
  /var/backups/xianyu-auto-reply
```

### 第一次手动备份

确认当前项目使用根目录 `docker-compose.yml` 正常运行，尤其是 MySQL 已健康，然后在项目根目录执行：

```bash
bash scripts/backup/create-backup.sh
```

脚本不会在命令行或日志中输出数据库密码。备份成功后会输出生成的完整备份目录；只有所有文件生成并通过基础检查后，目录内才会出现 `COMPLETE`。

默认的 `BACKUP_QUIESCE_SERVICES=true` 会在快照期间短暂、优雅停止 `backend-web`、`websocket` 和 `scheduler`，完成 MySQL、静态文件及浏览器数据归档后立即恢复原本正在运行的服务。MySQL、Redis 和 frontend 不会因创建备份而停止。若改为 `false`，服务不会中断，但正在变化的静态文件或浏览器 Profile 只能视为尽力一致。

### 验证备份

把下面的占位目录替换为实际备份目录：

```bash
bash scripts/backup/restore-backup.sh verify \
  /var/backups/xianyu-auto-reply/xianyu-auto-reply_backup_YYYYMMDD_HHMMSS
```

`verify` 是只读操作，会检查备份目录名称、`COMPLETE`、必需文件、SHA-256、gzip 文件以及 tar 归档的安全性，不会启动、停止或修改项目容器和数据。

### 恢复备份

恢复适用于新服务器重建，也可用于已有部署的灾难恢复。建议按以下顺序操作：

1. 在新服务器安装 Docker Engine、Docker Compose 和 Git。
2. 克隆项目，并尽量切换到生成备份时使用的代码版本。
3. 将完整备份目录复制到新服务器本地。
4. 先执行上述 `verify` 命令，确认校验全部通过。
5. 在项目根目录执行恢复命令，并按脚本提示确认：

   ```bash
   bash scripts/backup/restore-backup.sh restore \
     /var/backups/xianyu-auto-reply/xianyu-auto-reply_backup_YYYYMMDD_HHMMSS
   ```

6. 恢复脚本会先检查目标状态。如果存在 `.env`、卷数据或 MySQL 数据，必须在覆盖任何内容之前生成恢复前安全备份；安全备份失败时不会继续恢复。
7. 安全检查完成后，脚本才恢复根目录 `.env`，再准备并恢复 `static-files`、`browser_data`，启动 MySQL 并导入逻辑备份，最后恢复应用服务。
8. 恢复后检查 `docker compose ps`、前端、后端健康接口、静态/上传文件、WebSocket、浏览器登录状态和调度服务。

对已有部署执行恢复时，MySQL 必须能够启动且 `mysql`、`backend-web`、`websocket` 的现有 Compose 容器必须可用于生成安全备份。只剩卷、缺少原 `.env`、MySQL 无法导出或相关容器缺失时，脚本会保守中止，不会跳过安全备份继续覆盖旧数据。

恢复会覆盖目标部署中的持久数据，是破坏性操作。不要跳过校验或二次确认，也不要在恢复前手动删除原有卷。备份和恢复脚本不会使用、文档也不要求使用以下命令：

```text
docker compose down -v
docker volume rm
docker system prune
```

第一版不提供自动回滚。目标服务器存在数据时生成的恢复前安全备份应保留到人工验证恢复结果之后。

### 每天自动备份

先成功完成一次手动备份和 `verify`，再为同一个 Linux 用户配置 cron。以下示例每天凌晨 02:15 执行，并用 `flock` 防止任务重叠；请将项目路径替换为实际绝对路径：

```cron
15 2 * * * cd /opt/xianyu-auto-reply && /usr/bin/flock -n /var/backups/xianyu-auto-reply/.cron.lock /bin/bash scripts/backup/create-backup.sh >> /var/backups/xianyu-auto-reply/backup.log 2>&1
```

确保执行用户对备份目录、锁文件和日志文件具有相应权限。定期检查 cron 退出状态和日志，不能只依赖目录是否存在来判断备份成功。

### 验证备份确实可恢复

校验和成功只能证明文件没有损坏，不能替代恢复演练。建议至少每月或每季度在独立临时服务器或虚拟机中进行一次完整演练：

1. 从零克隆相同版本的项目。
2. 对备份执行 `verify`，再执行 `restore`。
3. 确认 MySQL 表和关键业务数据可查询。
4. 确认静态资源、用户上传文件和浏览器数据已恢复。
5. 确认所有服务正常运行，并完成一次实际登录和核心业务检查。

备份包中的 `.env` 和 `browser_data` 含敏感信息。备份目录应保持仅备份用户可读（目录 `0700`、文件 `0600`），不得放入代码仓库、公共网盘或未加密的共享目录。
