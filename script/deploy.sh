#!/bin/bash

# 简洁版DCAllocator部署脚本
# 用法: ./deploy.sh <network>
# 支持网络: cali, mainnet, anvil/localhost

set -e

NETWORK="$1"

if [ -z "$NETWORK" ]; then
  echo "用法: ./deploy.sh <network>"
  echo "支持网络: cali, mainnet, anvil/localhost"
  exit 1
fi

# 各网络默认RPC
case "$NETWORK" in
  anvil|localhost)
    DEFAULT_RPC="http://localhost:8545"
    ;;
  cali)
    DEFAULT_RPC="https://api.calibration.node.glif.io/rpc/v1"
    ;;
  mainnet)
    DEFAULT_RPC="https://api.node.glif.io/rpc/v1"
    ;;
  *)
    echo "不支持的网络: $NETWORK"
    exit 1
    ;;
esac

# 优先用环境变量RPC_URL，否则用默认
RPC_URL="${RPC_URL:-$DEFAULT_RPC}"

if [ -z "$PRIVATE_KEY" ]; then
  echo "请先设置PRIVATE_KEY环境变量"
  exit 1
fi

echo "部署网络: $NETWORK"
echo "RPC URL: $RPC_URL"

case "$NETWORK" in
  anvil|localhost)
    echo "本地部署..."
    forge script script/Deploy.s.sol:DeployScript --rpc-url "$RPC_URL" --broadcast --private-key "$PRIVATE_KEY"
    ;;
  cali)
    echo "Filecoin Calibration测试网部署..."
    forge script script/Deploy.s.sol:DeployScript --rpc-url "$RPC_URL" --broadcast --private-key "$PRIVATE_KEY" --legacy --slow --gas-price 5000000000 --gas-limit 100000000 --skip-simulation -vvvv
    ;;
  mainnet)
    echo "主网部署..."
    forge script script/Deploy.s.sol:DeployScript --rpc-url "$RPC_URL" --broadcast --private-key "$PRIVATE_KEY" --verify
    ;;
  *)
    echo "不支持的网络: $NETWORK"
    exit 1
    ;;
esac

echo "部署完成!" 