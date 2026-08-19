# Xianyu Remote Token Server

从中国大陆网络出口调用闲鱼 IM Token API，解决海外机房风控问题的中转服务。

## 📋 功能

✅ HTTP POST API 接口（FastAPI）
✅ X-API-Key 请求头验证
✅ Cookie 解析 + 用户 ID 提取
✅ 设备 ID 生成 + MD5 签名
✅ 闲鱼 IM Token API 调用
✅ 统一响应格式
✅ 完整日志记录（脱敏处理）
✅ Docker 部署支持
✅ 云函数部署支持
✅ 健康检查 + 连通性测试

## 🚀 快速开始

### Docker 部署

```bash
# 构建镜像
docker build -t xianyu-remote-token-server .

# 运行容器（设置 API_KEY）
docker run -d \
  -e API_KEY=your-32-char-secret-key \
  -e LOG_LEVEL=INFO \
  -e REQUEST_TIMEOUT=30 \
  -p 8000:8000 \
  --name xianyu-token-server \
  xianyu-remote-token-server

# 查看日志
docker logs -f xianyu-token-server

# 测试连通性
curl -X POST http://localhost:8000/test \
  -H "X-API-Key: your-32-char-secret-key"
```

### 本地开发运行

```bash
# 安装依赖
pip install -r requirements.txt

# 设置环境变量
export API_KEY="your-32-char-secret-key"
export LOG_LEVEL="DEBUG"

# 运行应用
python app.py
```

## 📡 API 接口

### 1. 获取 Token - `/invoke`

**请求**

```bash
POST /invoke
Content-Type: application/json
X-API-Key: your-32-char-secret-key

{
  "type": "xianyu_token",
  "data": {
    "cookies": "完整的闲鱼 Cookie 字符串"
  }
}
```

**成功响应 (200 OK)**

```json
{
  "success": true,
  "message": "取Token成功",
  "data": {
    "token": "50000000.9f0e5...",
    "device_id": "550e8400-e29b-41d4-a716-446655440000-unb123456",
    "api_mode": "web"
  }
}
```

### 2. 测试连通性 - `/test`

验证 API Key 和基本连接，不需要 Cookie。

**请求**

```bash
POST /test
X-API-Key: your-32-char-secret-key
```

### 3. 健康检查 - `/health`

```bash
GET /health
```

## 🔐 安全配置

### 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `API_KEY` | `""` | **必填**：32 位随机字符串 |
| `LOG_LEVEL` | `INFO` | 日志级别 |
| `REQUEST_TIMEOUT` | `30` | 闲鱼 API 超时（秒） |
| `LISTEN_HOST` | `0.0.0.0` | 监听地址 |
| `LISTEN_PORT` | `8000` | 监听端口 |

### 密钥生成

```bash
# Linux/Mac
openssl rand -hex 16

# Python
python -c "import secrets; print(secrets.token_hex(16))"
```

## 🏃 主平台集成

在主项目的系统设置中配置：

```python
INSERT INTO system_setting (key, value) VALUES 
  ('token.remote_url', 'http://xianyu-token-server:8000/invoke'),
  ('token.remote_secret_key', 'your-32-char-secret-key');
```

## ☁️ 云函数部署

详见 `CLOUD_DEPLOYMENT.md`

支持：
- 阿里云函数计算
- 腾讯云函数
- 华为云 FunctionGraph

## 🧪 本地测试

```bash
chmod +x test.sh
./test.sh
```

## 📊 性能指标

- 镜像大小：~150-200MB
- 平均响应时间：~500ms
- 并发能力：100-500（取决于闲鱼 API 限制）

## 📝 日志示例

```
2026-08-19 10:00:05 - INFO - 已生成设备 ID: 550e8400-e29b-41d4... - IP: 192.168.1.100
2026-08-19 10:00:10 - INFO - Token 获取成功 - IP: 192.168.1.100
2026-08-19 10:00:15 - WARNING - 非法请求 - IP: 192.168.1.101，API Key: 缺失
```

## 🔧 故障排查

### 连接超时

增加 `REQUEST_TIMEOUT` 环境变量（如 60）

### API Key 无效

确认请求头拼写正确：`X-API-Key`（区分大小写）

### Cookie 解析失败

确保 Cookie 中包含 `unb` 或 `munb` 字段

## 📄 许可证

MIT License

## 🤝 相关项目

主项目：https://github.com/koookkong90-svg/xianyu-auto-reply
