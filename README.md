# DCAllocator

DCAllocator是一个基于多签地址的质押与罚没管理智能合约系统，用于管理用户对特定issue的FIL质押，并通过多签机制实现对违规行为的罚没处理。

## 项目概述

DCAllocator合约主要实现以下功能：

1. **质押管理**：
   - 用户可以对特定issue进行FIL质押
   - 每个issue只能被质押一次，初始质押后可通过stakeMore函数增加质押金额
   - 质押后需等待挑战期(默认180天)才能取回质押
   - 增加质押金额会重置质押时间

2. **多签地址管理**：
   - 合约拥有一个多签地址（committeeMultisig），只有该地址可以执行罚没操作
   - 合约拥有者可以设置或更换多签地址

3. **罚没机制**：
   - 只有多签地址可以对质押执行罚没（slash）
   - 被罚没的资金将转移到指定的保险库地址

4. **活跃与历史质押管理**：
   - 合约维护一个活跃问题列表
   - 支持查询所有历史质押（包括已结束和被罚没）
   - 支持分页查询所有历史质押，便于链下同步

## 主要接口

### 质押相关
- `stake(uint256 issue)` - 对特定issue进行质押
- `stakeMore(uint256 issue)` - 增加对已有issue的质押金额
- `unstake(uint256 issue)` - 在挑战期结束后取回质押

### 罚没相关
- `slash(uint256 issue, string reason)` - 多签地址直接执行罚没

### 配置相关
- `setVault(address _vault)` - 设置保险库地址
- `setChallengePeriod(uint256 _challengePeriod)` - 设置挑战期时长（单位：天）
- `setCommitteeMultisig(address _committeeMultisig)` - 设置/更换多签地址
- `transferOwnership(address newOwner)` - 迁移合约owner权限到新地址

### 查询相关
- `getAllActiveStakes()` - 获取所有活跃质押信息
- `getAllStakes()` - 获取所有历史质押信息（不建议链上大数据量调用）
- `getAllStakesPaged(uint256 offset, uint256 limit)` - 分页获取历史质押信息，推荐链下同步使用
- `getActiveIssuesCount()` - 获取当前活跃问题数量

### 状态变量
- `vault`：保险库地址，被罚没的资金将转移到此地址
- `committeeMultisig`：多签地址，只有该地址可以执行罚没
- `owner`：合约拥有者地址
- `challengePeriod`：挑战期时长，默认为180天
- `activeIssues`：活跃问题列表（内部）
- `allIssues`：所有出现过的issue列表（内部）
- `stakes`：issue ID => Stake结构体，存储质押信息

### 数据结构
```solidity
struct Stake {
    address user;     // 质押用户地址
    uint256 amount;   // 质押金额
    uint256 timestamp; // 质押时间戳
    bool isSlash;     // 是否已被罚没
}
```

### 事件
- `Staked(uint256 issue, address indexed user, uint256 amount, uint256 timestamp)`：质押事件
- `Unstaked(uint256 issue, address indexed user, uint256 amount, uint256 timestamp)`：取回质押事件
- `Slashed(uint256 issue, address indexed user, uint256 amount, uint256 timestamp, address committeeMultisig, string reason)`：罚没事件
- `StakedMore(uint256 issue, address indexed user, uint256 additionalAmount, uint256 newAmount, uint256 timestamp)`：增加质押金额事件

## 安全特性
- 只有合约拥有者可以修改关键参数（挑战期、保险库地址、多签地址）
- 只有多签地址可以执行罚没
- 质押后需等待挑战期才能取回质押
- 被罚没的资金将转移到指定的保险库地址
- 使用重入锁防止重入攻击
- 质押、取回、罚没等操作均有事件记录
- owner权限可通过transferOwnership(address newOwner)迁移，迁移后只有新owner可再管理合约

## 部署与使用

### 部署
推荐使用一键部署脚本：
```shell
# 先设置私钥和（可选）自定义RPC
export PRIVATE_KEY=你的私钥
# export RPC_URL=自定义RPC（可选）

# 部署到本地anvil
./script/deploy.sh anvil
# 部署到Filecoin Calibration测试网
./script/deploy.sh cali
# 部署到Filecoin主网
./script/deploy.sh mainnet
```
- 脚本会根据网络自动选择默认RPC（如未设置RPC_URL环境变量）。
- 只需设置PRIVATE_KEY，其它参数可在合约部署后通过set函数配置。
- 如需自定义RPC节点，可提前设置 `RPC_URL` 环境变量。

### 主要功能示例
```solidity
// 质押 1 FIL 到 issue #123
dcallocator.stake{value: 1 ether}(123);
// 增加质押金额
dcallocator.stakeMore{value: 0.5 ether}(123);
// 取回质押
dcallocator.unstake(123);
// 多签地址直接罚没
dcallocator.slash(123, "违规原因");
```

## 开发工具
本项目使用Foundry开发框架：
- **Forge**: 用于测试和编译合约
- **Cast**: 用于与合约交互和发送交易
- **Anvil**: 本地节点模拟

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

## 单元测试
- 已覆盖质押、追加、取回、罚没、参数设置、分页查询等主流程和异常分支
- 测试文件：`test/DCAllocator.t.sol`

## 文档
- 详细接口文档见：`docs/interface.md`
- 更多Foundry信息请参考：https://book.getfoundry.sh/
