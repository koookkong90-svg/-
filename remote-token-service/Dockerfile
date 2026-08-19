# 使用官方 Python 运行时作为基础镜像
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 安装系统依赖（如果需要）
RUN apt-get update && apt-get install -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# 复制 requirements.txt 并安装 Python 依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY app.py .

# 暴露端口
EXPOSE 8000

# 设置环境变量默认值
ENV API_KEY="" \
    LOG_LEVEL="INFO" \
    REQUEST_TIMEOUT="30" \
    LISTEN_HOST="0.0.0.0" \
    LISTEN_PORT="8000"

# 启动应用
CMD ["python", "app.py"]
