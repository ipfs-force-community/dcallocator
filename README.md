# DCAllocator

DCAllocator是一个基于多签委员会的质押与罚没管理智能合约系统，用于管理用户对特定issue的ETH质押，并通过委员会多签机制实现对违规行为的罚没处理。

## 项目概述

DCAllocator合约主要实现以下功能：

1. **质押管理**：
   - 用户可以对特定issue进行ETH质押
   - 每个issue只能被质押一次，初始质押后可通过stakeMore函数增加质押金额
   - 质押后需等待挑战期(默认180天)才能取回质押
   - 增加质押金额会重置质押时间

2. **委员会管理**：
   - 合约由多签委员会成员共同管理
   - 委员会成员可以对质押提出罚没提议
   - 当罚没提议达到阈值时，质押将被罚没并转移到保险库
   - 合约拥有者可以添加或移除委员会成员
   - 委员会成员数量有上限(maxCommitteeSize)

3. **罚没机制**：
   - 委员会成员可以对质押发起罚没提议
   - 当提议数量达到阈值时，质押将被罚没
   - 被罚没的资金将转移到指定的保险库地址

4. **活跃问题管理**：
   - 合约维护一个活跃问题列表
   - 当质押被取回或罚没时，相应的问题将从活跃列表中移除

## 安全特性

- 只有合约拥有者可以修改关键参数(挑战期、保险库地址)
- 只有合约拥有者可以管理委员会成员
- 委员会成员数量不能低于阈值，确保多签机制正常运行
- 每个委员会成员对同一issue只能提交一次罚没提议

## 部署与使用

### 部署

使用Foundry部署DCAllocator合约：

```shell
$ forge script script/DCAllocator.s.sol:DCAllocatorScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

部署时需要指定以下参数：
- 初始委员会成员地址列表
- 罚没阈值（多少委员会成员同意后执行罚没）
- 最大委员会成员数量

### 主要功能接口

1. **质押相关**：
   - `stake(uint issue)` - 对特定issue进行质押
   - `stakeMore(uint issue)` - 增加对已有issue的质押金额
   - `unstake(uint issue)` - 在挑战期结束后取回质押

2. **委员会管理**：
   - `addCommitteeMember(address _member)` - 添加委员会成员
   - `removeCommitteeMember(address _member)` - 移除委员会成员
   - `isCommitteeMember(address _address)` - 检查地址是否是委员会成员

3. **罚没相关**：
   - `slash(uint issue)` - 委员会成员提议罚没特定issue的质押
   - `hasReachedThreshold(uint issue)` - 检查罚没提议是否达到阈值
   - `getSlashProposals(uint issue)` - 获取某个issue的所有罚没提议

4. **配置相关**：
   - `setVault(address _vault)` - 设置保险库地址
   - `setChallengePeriod(uint256 _challengePeriod)` - 设置挑战期时长

## 开发工具

本项目使用Foundry开发框架：

- **Forge**: 用于测试和编译合约
- **Cast**: 用于与合约交互和发送交易
- **Anvil**: 本地以太坊节点模拟
- **Chisel**: Solidity REPL工具

### 构建

```shell
$ forge build
```

### 测试

```shell
$ forge test
```

### 格式化

```shell
$ forge fmt
```

## 文档

更多关于Foundry的信息，请参考：https://book.getfoundry.sh/
