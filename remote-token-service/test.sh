#!/bin/bash

# 本地测试脚本

set -e

# 配置
API_KEY=${API_KEY:-"test-api-key-32-chars-exactly"}
SERVER_URL=${SERVER_URL:-"http://localhost:8000"}
TEST_TIMEOUT=${TEST_TIMEOUT:-10}

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========== Xianyu Remote Token Server 测试脚本 ==========${NC}\n"

# 1. 检查服务是否运行
echo -e "${YELLOW}[1/5] 检查服务连接性...${NC}"
if ! curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "$SERVER_URL/health" | grep -q "200"; then
    echo -e "${RED}❌ 无法连接到服务: $SERVER_URL${NC}"
    echo "请确保服务已启动: python app.py"
    exit 1
fi
echo -e "${GREEN}✅ 服务连接成功${NC}\n"

# 2. 测试健康检查端点
echo -e "${YELLOW}[2/5] 测试健康检查 (/health)...${NC}"
HEALTH=$(curl -s "$SERVER_URL/health")
if echo "$HEALTH" | grep -q '"status":"ok"'; then
    echo -e "${GREEN}✅ 健康检查通过${NC}"
    echo "   响应: $HEALTH\n"
else
    echo -e "${RED}❌ 健康检查失败${NC}"
    echo "   响应: $HEALTH"
    exit 1
fi

# 3. 测试连通性测试端点
echo -e "${YELLOW}[3/5] 测试连通性 (/test)...${NC}"
TEST_RESULT=$(curl -s -X POST "$SERVER_URL/test" \
    -H "X-API-Key: $API_KEY")

if echo "$TEST_RESULT" | grep -q '"success":true'; then
    echo -e "${GREEN}✅ 连通性测试通过${NC}"
    echo "   响应: $TEST_RESULT\n"
else
    echo -e "${RED}❌ 连通性测试失败${NC}"
    echo "   响应: $TEST_RESULT"
    exit 1
fi

# 4. 测试无效 API Key
echo -e "${YELLOW}[4/5] 测试无效 API Key 拒绝...${NC}"
INVALID_KEY=$(curl -s -w "\n%{http_code}" -X POST "$SERVER_URL/invoke" \
    -H "X-API-Key: wrong-key" \
    -H "Content-Type: application/json" \
    -d '{"type":"xianyu_token","data":{"cookies":""}}')

HTTP_CODE=$(echo "$INVALID_KEY" | tail -n 1)
if [ "$HTTP_CODE" = "403" ]; then
    echo -e "${GREEN}✅ API Key 验证正确（返回 403）${NC}\n"
else
    echo -e "${RED}❌ API Key 验证失败（返回 $HTTP_CODE，期望 403）${NC}"
    exit 1
fi

# 5. 测试缺失 Cookie
echo -e "${YELLOW}[5/5] 测试缺失 Cookie 处理...${NC}"
NO_COOKIE=$(curl -s -X POST "$SERVER_URL/invoke" \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"type":"xianyu_token","data":{"cookies":""}}')

if echo "$NO_COOKIE" | grep -q '"success":false'; then
    if echo "$NO_COOKIE" | grep -q 'Cookie'; then
        echo -e "${GREEN}✅ Cookie 验证正确${NC}"
        echo "   响应: $NO_COOKIE\n"
    else
        echo -e "${RED}❌ 错误信息不正确${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ 应该返回失败状态${NC}"
    exit 1
fi

echo -e "${GREEN}========== 所有测试通过！✅ ==========${NC}"
echo -e "\n${YELLOW}下一步:${NC}"
echo "1. 配置主平台系统设置中的远程 Token 接口"
echo "   URL: $SERVER_URL/invoke"
echo "   密钥: $API_KEY"
echo "2. 点击测试连接按钮验证"
echo "3. 部署到云环境（Docker / 云函数）"
