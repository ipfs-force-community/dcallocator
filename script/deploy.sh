#!/bin/bash

# 部署DCAllocator合约的脚本
# 用法: ./deploy.sh [network] [options]

set -e

# 默认参数
NETWORK="cali"
DEFAULT_RPC_URL="https://filecoin-calibration.chainup.net/rpc/v1"
COMMITTEE="0x70997970C51812dc3A010C7d01b50e0d17dc79C8,0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,0x90F79bf6EB2c4f870365E785982E1f101E93b906"
THRESHOLD=2
MAX_COMMITTEE_SIZE=5
VAULT="0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"
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
    --max-committee-size)
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
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

# 设置环境变量
export COMMITTEE="$COMMITTEE"
export THRESHOLD="$THRESHOLD"
export MAX_COMMITTEE_SIZE="$MAX_COMMITTEE_SIZE"
export VAULT="$VAULT"

# 显示配置信息
echo "部署配置:"
echo "网络: $NETWORK"
echo "委员会成员: $COMMITTEE"
echo "阈值: $THRESHOLD"
echo "最大委员会人数: $MAX_COMMITTEE_SIZE"
echo "保险库地址: $VAULT"
echo "挑战期 (天): $CHALLENGE_PERIOD"

# 确认部署
read -p "确认部署? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "部署已取消"
  exit 0
fi

# 执行部署
echo "开始部署..."

if [ "$NETWORK" = "anvil" ] || [ "$NETWORK" = "localhost" ]; then
  # 本地部署
  forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
elif [ "$NETWORK" = "cali" ]; then
  # Filecoin Calibration测试网部署
  if [ -z "$PRIVATE_KEY" ]; then
    echo "错误: 部署到测试网需要设置PRIVATE_KEY环境变量"
    exit 1
  fi
  
  # 使用默认RPC URL或环境变量中的RPC URL
  RPC_URL=${RPC_URL:-$DEFAULT_RPC_URL}
  
  forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY --verify
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
  
  # 再次确认主网部署
  echo "警告: 你正在部署到以太坊主网!"
  read -p "确认主网部署? (输入 'CONFIRM' 确认): " -r
  if [[ ! $REPLY = "CONFIRM" ]]; then
    echo "主网部署已取消"
    exit 0
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
  
  # 再次确认主网部署
  echo "警告: 你正在部署到Filecoin主网!"
  read -p "确认Filecoin主网部署? (输入 'CONFIRM' 确认): " -r
  if [[ ! $REPLY = "CONFIRM" ]]; then
    echo "Filecoin主网部署已取消"
    exit 0
  fi
  
  forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY --verify
else
  echo "错误: 不支持的网络 '$NETWORK'"
  exit 1
fi

echo "部署完成!"
