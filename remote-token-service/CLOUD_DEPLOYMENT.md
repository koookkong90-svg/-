"""
云函数部署配置

支持阿里云、腾讯云、华为云等云厂商
"""

# ============ 阿里云函数计算部署 ============

# 1. 创建函数流程
# - 登录 https://fc.console.aliyun.com/
# - 创建函数 -> 选择"从零开始创建"
# - 函数名称: xianyu-remote-token-server
# - 运行时: Python 3.11
# - 内存: 512 MB（可根据需要调整）
# - 超时: 30 秒

# 2. 部署代码
# - 打包: zip -r code.zip app.py requirements.txt
# - 上传代码 zip 文件

# 3. 配置环境变量
# 在函数详情 -> 环境变量 中添加：
# API_KEY=your-32-char-secret-key
# LOG_LEVEL=INFO
# REQUEST_TIMEOUT=30

# 4. 配置 HTTP 触发器
# - 创建触发器 -> HTTP
# - 路由: /invoke
# - 方法: POST
# - 认证: 无认证（通过 X-API-Key 头部验证）
# - 请求路径: /invoke

# 5. 测试
# curl -X POST https://your-account-id.cn-hangzhou.fc.aliyuncs.com/2016-08-15/proxy/xianyu-remote-token-server/invoke \
#   -H "X-API-Key: your-32-char-secret-key" \
#   -H "Content-Type: application/json" \
#   -d '{"type":"xianyu_token","data":{"cookies":"..."}}'


# ============ 腾讯云函数部署 ============

# 1. 创建函数流程
# - 登录 https://console.cloud.tencent.com/scf/
# - 函数管理 -> 新建 -> 自定义创建
# - 函数名称: xianyu-remote-token-server
# - 运行时环境: Python 3.11
# - 内存: 512 MB
# - 执行超时: 30 秒

# 2. 上传代码
# - 打包: zip -r code.zip app.py requirements.txt
# - 在函数代码中选择"上传 ZIP 文件"或"上传文件夹"

# 3. 环境变量配置
# 函数配置 -> 环境变量 中添加：
# API_KEY | your-32-char-secret-key
# LOG_LEVEL | INFO
# REQUEST_TIMEOUT | 30

# 4. 创建触发器
# - 创建触发器 -> API 网关触发器
# - 集成响应: 启用
# - 请求方法: POST
# - 发布环境: 发布

# 5. 测试
# curl -X POST https://your-service-id.apigw.tencentcs.com/invoke \
#   -H "X-API-Key: your-32-char-secret-key" \
#   -H "Content-Type: application/json" \
#   -d '{"type":"xianyu_token","data":{"cookies":"..."}}'


# ============ 华为云函数工作流部署 ============

# 1. 创建函数
# - 登录 https://console.huaweicloud.com/functiongraph/
# - 创建函数 -> 选择"创建新函数"
# - 函数名称: xianyu-remote-token-server
# - 运行时语言: Python 3.11
# - 内存: 512 MB
# - 超时时间: 30 秒

# 2. 代码上传
# - 打包: zip -r code.zip app.py requirements.txt
# - 上传代码包

# 3. 环境变量设置
# 在环境变量中添加：
# API_KEY=your-32-char-secret-key
# LOG_LEVEL=INFO
# REQUEST_TIMEOUT=30

# 4. API 网关配置
# - 创建 API -> 选择此函数
# - 请求方法: POST
# - 请求路径: /invoke

# 5. 测试
# curl -X POST https://your-gateway-url/invoke \
#   -H "X-API-Key: your-32-char-secret-key" \
#   -H "Content-Type: application/json" \
#   -d '{"type":"xianyu_token","data":{"cookies":"..."}}'


# ============ 通用部署建议 ============

# 内存分配:
# - 最小: 256 MB (不推荐，可能超时)
# - 推荐: 512 MB (性能和成本均衡)
# - 高并发: 1024 MB+ (更快响应)

# 超时设置:
# - 最小: 10 秒 (不推荐)
# - 推荐: 30 秒 (适应大多数网络条件)
# - 高延迟地区: 60 秒

# 冷启动优化:
# - 使用容器镜像部署（比 ZIP 包快）
# - 配置预留并发（按需付费）
# - 定期调用保温（发送健康检查请求）

# 日志配置:
# - 确保云函数服务有权访问日志服务
# - 配置日志级别为 INFO（生产环境）
# - 定期清理过期日志

# 监控告警:
# - 监控调用错误率
# - 监控响应时间 P95/P99
# - 配置错误告警（>5% 失败率）
