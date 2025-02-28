#!/bin/bash

# 部署DCAllocator合约的脚本
# 用法: ./deploy.sh [network] [options]

set -e

# 默认参数
NETWORK="cali"
DEFAULT_RPC_URL="https://api.calibration.node.glif.io/rpc/v1"
COMMITTEE="0x3dBcFd9a5d0534c675f529Aa0006918e4a658033,0x5a15CcF478922873375468626a8c44ffEd981802,0x1D38DB15DC600Bd73898F651d83D83808f6131Dd"
THRESHOLD=2
MAX_COMMITTEE_SIZE=5
VAULT="0xEb756AAef793125EeFD409Ef3Bb20787FBC25c10"
CHALLENGE_PERIOD=180  # 180天

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --network)
      NETWORK="$2"
      shift 2
      ;;
    --committee)
      COMMITTEE="$2"
      shift 2
      ;;
    --threshold)
      THRESHOLD="$2"
      shift 2
      ;;
    --max-committee)
      MAX_COMMITTEE_SIZE="$2"
      shift 2
      ;;
    --vault)
      VAULT="$2"
      shift 2
      ;;
    --challenge-period)
      CHALLENGE_PERIOD="$2"
      shift 2
      ;;
    --help)
      echo "用法: ./deploy.sh [options]"
      echo "选项:"
      echo "  --network <network>         指定网络 (cali, mainnet, anvil, localhost)"
      echo "  --committee <addresses>     委员会成员地址，用逗号分隔"
      echo "  --threshold <number>        委员会阈值"
      echo "  --max-committee <number>    最大委员会人数"
      echo "  --vault <address>           保险库地址"
      echo "  --challenge-period <days>   挑战期（天）"
      echo "  --help                      显示帮助信息"
      exit 0
      ;;
    *)
      echo "未知选项: $1"
      exit 1
      ;;
  esac
done

# 导出环境变量，供Forge脚本使用
export COMMITTEE="$COMMITTEE"
export THRESHOLD="$THRESHOLD"
export MAX_COMMITTEE_SIZE="$MAX_COMMITTEE_SIZE"
export VAULT="$VAULT"
export CHALLENGE_PERIOD="$CHALLENGE_PERIOD"

# 显示配置信息
echo "部署配置:"
echo "网络: $NETWORK"
echo "委员会成员: $COMMITTEE"
echo "阈值: $THRESHOLD"
echo "最大委员会人数: $MAX_COMMITTEE_SIZE"
echo "保险库地址: $VAULT"
echo "挑战期 (天): $CHALLENGE_PERIOD"

# 确认部署到主网
if [ "$NETWORK" = "mainnet" ] || [ "$NETWORK" = "filecoin" ]; then
  echo -n "你确定要部署到主网吗? [y/N] "
  read confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "部署已取消"
    exit 0
  fi
fi

# 执行部署
echo "开始部署..."

if [ "$NETWORK" = "anvil" ] || [ "$NETWORK" = "localhost" ]; then
  # 本地部署
  if [ -z "$PRIVATE_KEY" ]; then
    echo "错误: 部署到本地网络需要设置PRIVATE_KEY环境变量"
    echo "可以使用anvil默认账户的私钥: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    exit 1
  fi
  forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --broadcast --private-key $PRIVATE_KEY
elif [ "$NETWORK" = "cali" ]; then
  # Filecoin Calibration测试网部署
  if [ -z "$PRIVATE_KEY" ]; then
    echo "错误: 部署到测试网需要设置PRIVATE_KEY环境变量"
    exit 1
  fi
  # 使用默认RPC URL或环境变量中的RPC URL
  RPC_URL=${RPC_URL:-$DEFAULT_RPC_URL}
  echo "使用RPC URL: $RPC_URL"
  
  # 为Filecoin网络设置特定参数
  # 首先获取对应的Filecoin地址
  echo "获取Filecoin地址..."
  SENDER_ADDR=$(cast wallet address --private-key "$PRIVATE_KEY")
  echo "以太坊地址: $SENDER_ADDR"
  
  # 使用Filecoin特定参数
  forge script script/Deploy.s.sol:DeployScript \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    --legacy \
    --slow \
    --gas-price 1000000000 \
    --gas-limit 20000000 \
    --skip-simulation \
    -vvvv
elif [ "$NETWORK" = "sepolia" ]; then
  # Sepolia测试网部署
  if [ -z "$PRIVATE_KEY" ]; then
    echo "错误: 部署到测试网需要设置PRIVATE_KEY环境变量"
    exit 1
  fi
  if [ -z "$RPC_URL" ]; then
    echo "错误: 部署到测试网需要设置RPC_URL环境变量"
    exit 1
  fi
  forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY --verify
elif [ "$NETWORK" = "mainnet" ]; then
  # 主网部署
  if [ -z "$PRIVATE_KEY" ]; then
    echo "错误: 部署到主网需要设置PRIVATE_KEY环境变量"
    exit 1
  fi
  # 检查RPC URL
  if [ -z "$RPC_URL" ]; then
    echo "错误: 部署到主网需要设置RPC_URL环境变量"
    exit 1
  fi
  forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY --verify
elif [ "$NETWORK" = "filecoin" ]; then
  # Filecoin主网部署
  if [ -z "$PRIVATE_KEY" ]; then
    echo "错误: 部署到Filecoin主网需要设置PRIVATE_KEY环境变量"
    exit 1
  fi
  # 检查RPC URL，如果未设置则使用默认值
  RPC_URL=${RPC_URL:-"https://api.node.glif.io/rpc/v1"}
  echo "使用RPC URL: $RPC_URL"
  
  # 为Filecoin网络设置特定参数
  # 首先获取对应的Filecoin地址
  echo "获取Filecoin地址..."
  SENDER_ADDR=$(cast wallet address --private-key "$PRIVATE_KEY")
  echo "以太坊地址: $SENDER_ADDR"
  
  # 使用Filecoin特定参数
  forge script script/Deploy.s.sol:DeployScript \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    --legacy \
    --slow \
    --gas-price 1000000000 \
    --gas-limit 20000000 \
    --skip-simulation \
    -vvvv
else
  echo "错误: 不支持的网络 '$NETWORK'"
  exit 1
fi

echo "部署完成!"
