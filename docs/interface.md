# DCAllocator 接口文档

## 目录

- [概述](#概述)
- [合约地址](#合约地址)
- [合约功能](#合约功能)
  - [1. 质押管理](#1-质押管理)
    - [1.1 质押 (stake)](#11-质押-stake)
    - [1.2 增加质押金额 (stakeMore)](#12-增加质押金额-stakemore)
    - [1.3 取回质押 (unstake)](#13-取回质押-unstake)
  - [2. 委员会管理](#2-委员会管理)
    - [2.1 添加委员会成员 (addCommitteeMember)](#21-添加委员会成员-addcommitteemember)
    - [2.2 移除委员会成员 (removeCommitteeMember)](#22-移除委员会成员-removecommitteemember)
    - [2.3 检查是否为委员会成员 (isCommitteeMember)](#23-检查是否为委员会成员-iscommitteemember)
  - [3. 罚没机制](#3-罚没机制)
    - [3.1 罚没提议 (slash)](#31-罚没提议-slash)
    - [3.2 检查是否达到罚没阈值 (hasReachedThreshold)](#32-检查是否达到罚没阈值-hasreachedthreshold)
    - [3.3 获取罚没提议 (getSlashProposals)](#33-获取罚没提议-getslashproposals)
  - [4. 活跃问题管理](#4-活跃问题管理)
    - [4.1 获取活跃问题数量 (getActiveIssuesCount)](#41-获取活跃问题数量-getactiveissuescount)
  - [5. 合约配置](#5-合约配置)
    - [5.1 设置挑战期 (setChallengePeriod)](#51-设置挑战期-setchallengeperiod)
    - [5.2 设置保险库地址 (setVault)](#52-设置保险库地址-setvault)
- [状态变量](#状态变量)
  - [公共变量](#公共变量)
  - [映射](#映射)
- [数据结构](#数据结构)
  - [Stake 结构体](#stake-结构体)
- [事件](#事件)
- [安全特性](#安全特性)
- [使用示例](#使用示例)
  - [质押 FIL](#质押-fil)
  - [增加质押金额](#增加质押金额)
  - [取回质押](#取回质押)
  - [提议罚没](#提议罚没)
- [部署参数](#部署参数)
- [注意事项](#注意事项)

## 概述

DCAllocator 是一个基于多签委员会的质押与罚没管理智能合约，用于管理用户对特定 issue 的 FIL 质押。合约支持质押管理、委员会管理、罚没机制和活跃问题管理等功能。

## 合约地址

0xEC1a8315b5cF542BAA6601eE73008C65AA9b28F3

访问一下地址进行操作，可以读写智能合约。

https://calibration.filscan.io/address/0xEC1a8315b5cF542BAA6601eE73008C65AA9b28F3/#contract_verify

## 合约功能

### 1. 质押管理

#### 1.1 质押 (stake)

用户可以对特定 issue 进行 FIL 质押。

**函数签名:**
```solidity
function stake(uint256 issue) public payable
```

**参数:**
- `issue`: issue 的唯一标识符

**要求:**
- 质押金额必须大于 0
- 指定的 issue 尚未被质押

**事件:**
- `Staked(uint256 issue, address indexed user, uint256 amount, uint256 timestamp)`

#### 1.2 增加质押金额 (stakeMore)

用户可以增加对已有 issue 的质押金额。

**函数签名:**
```solidity
function stakeMore(uint256 issue) public payable
```

**参数:**
- `issue`: 已质押的 issue 标识符

**要求:**
- 调用者必须是原始质押者
- 质押未被罚没
- 增加的金额必须大于 0

**事件:**
- `StakedMore(uint256 issue, address indexed user, uint256 additionalAmount, uint256 newAmount, uint256 timestamp)`

#### 1.3 取回质押 (unstake)

当质押时间超过挑战期后，用户可以取回质押。

**函数签名:**
```solidity
function unstake(uint256 issue) public
```

**参数:**
- `issue`: 已质押的 issue 标识符

**要求:**
- 调用者必须是原始质押者
- 质押未被罚没
- 质押时间已超过挑战期

**事件:**
- `Unstaked(uint256 issue, address indexed user, uint256 amount, uint256 timestamp)`

### 2. 委员会管理

#### 2.1 添加委员会成员 (addCommitteeMember)

添加新的委员会成员，仅合约拥有者可调用。

**函数签名:**
```solidity
function addCommitteeMember(address _member) public onlyOwner
```

**参数:**
- `_member`: 要添加的委员会成员地址

**要求:**
- 指定地址不是现有委员会成员
- 委员会成员数量未达到上限

#### 2.2 移除委员会成员 (removeCommitteeMember)

移除现有委员会成员，仅合约拥有者可调用。

**函数签名:**
```solidity
function removeCommitteeMember(address _member) public onlyOwner
```

**参数:**
- `_member`: 要移除的委员会成员地址

**要求:**
- 指定地址是现有委员会成员
- 移除后委员会成员数量不能低于阈值

#### 2.3 检查是否为委员会成员 (isCommitteeMember)

检查指定地址是否为委员会成员。

**函数签名:**
```solidity
function isCommitteeMember(address _address) public view returns (bool)
```

**参数:**
- `_address`: 要检查的地址

**返回值:**
- `bool`: 如果是委员会成员则返回 true，否则返回 false

### 3. 罚没机制

#### 3.1 罚没提议 (slash)

委员会成员可以对质押发起罚没提议。

**函数签名:**
```solidity
function slash(uint256 issue) public onlyCommittee
```

**参数:**
- `issue`: 要罚没的 issue 标识符

**要求:**
- 调用者必须是委员会成员
- 指定的 issue 必须已被质押
- 质押尚未被罚没

**事件:**
- `eventAddSlashProposal(uint256 issue, address indexed user, uint256 amount, uint256 timestamp, address proposer)`
- 当达到阈值时: `Slashed(uint256 issue, address indexed user, uint256 amount, uint256 timestamp, address[] committeeMembers)`

#### 3.2 检查是否达到罚没阈值 (hasReachedThreshold)

检查某个 issue 的罚没提议是否达到阈值。

**函数签名:**
```solidity
function hasReachedThreshold(uint256 issue) public view returns (bool)
```

**参数:**
- `issue`: 要检查的 issue 标识符

**返回值:**
- `bool`: 如果达到阈值则返回 true，否则返回 false

#### 3.3 获取罚没提议 (getSlashProposals)

获取某个 issue 的所有罚没提议。

**函数签名:**
```solidity
function getSlashProposals(uint256 issue) public view returns (address[] memory)
```

**参数:**
- `issue`: 要查询的 issue 标识符

**返回值:**
- `address[] memory`: 提议罚没的委员会成员地址数组

### 4. 活跃问题管理

#### 4.1 获取活跃问题数量 (getActiveIssuesCount)

获取当前活跃问题的数量。

**函数签名:**
```solidity
function getActiveIssuesCount() public view returns (uint256)
```

**返回值:**
- `uint256`: 活跃问题的数量

### 5. 合约配置

#### 5.1 设置挑战期 (setChallengePeriod)

设置质押的挑战期时长，仅合约拥有者可调用。

**函数签名:**
```solidity
function setChallengePeriod(uint256 _challengePeriod) public onlyOwner
```

**参数:**
- `_challengePeriod`: 新的挑战期时长（单位：天）

#### 5.2 设置保险库地址 (setVault)

设置被罚没资金转移的目标地址，仅合约拥有者可调用。

**函数签名:**
```solidity
function setVault(address _vault) public onlyOwner
```

**参数:**
- `_vault`: 新的保险库地址

**要求:**
- 新地址不能为零地址

## 状态变量

### 公共变量

- `vault`: 保险库地址，被罚没的资金将转移到此地址
- `multiSigCommittee`: 委员会成员地址数组
- `threshold`: 罚没阈值，决定多少委员会成员同意后才能执行罚没操作
- `committeeTotal`: 当前委员会成员总数
- `maxCommitteeSize`: 委员会最大人数
- `owner`: 合约拥有者地址
- `challengePeriod`: 挑战期时长，默认为180天
- `activeIssues`: 活跃问题列表

### 映射

- `stakes`: issue ID => Stake 结构体，存储质押信息
- `issueToIndex`: issue ID => 数组索引，用于快速查找和删除活跃问题
- `slashProposals`: issue ID => 提议者地址数组，记录每个 issue 的罚没提议

## 数据结构

### Stake 结构体

```solidity
struct Stake {
    address user;     // 质押用户地址
    uint256 amount;   // 质押金额
    uint256 timestamp; // 质押时间戳
    bool isSlash;     // 是否已被罚没
}
```

## 事件

- `Staked(uint256 issue, address indexed user, uint256 amount, uint256 timestamp)`: 质押事件
- `Unstaked(uint256 issue, address indexed user, uint256 amount, uint256 timestamp)`: 取回质押事件
- `Slashed(uint256 issue, address indexed user, uint256 amount, uint256 timestamp, address[] committeeMembers)`: 罚没事件
- `eventAddSlashProposal(uint256 issue, address indexed user, uint256 amount, uint256 timestamp, address proposer)`: 添加罚没提议事件
- `StakedMore(uint256 issue, address indexed user, uint256 additionalAmount, uint256 newAmount, uint256 timestamp)`: 增加质押金额事件

## 安全特性

- 只有合约拥有者可以修改关键参数（挑战期、保险库地址）
- 只有合约拥有者可以管理委员会成员
- 委员会成员数量不能低于阈值，确保多签机制正常运行
- 每个委员会成员对同一 issue 只能提交一次罚没提议
- 质押后需等待挑战期才能取回质押
- 被罚没的资金将转移到指定的保险库地址

## 使用示例

### 质押 FIL

```solidity
// 质押 1 FIL 到 issue #123
dcallocator.stake{value: 1 ether}(123);
```

### 增加质押金额

```solidity
// 为 issue #123 增加 0.5 FIL 的质押
dcallocator.stakeMore{value: 0.5 ether}(123);
```

### 取回质押

```solidity
// 取回 issue #123 的质押
dcallocator.unstake(123);
```

### 提议罚没

```solidity
// 委员会成员提议罚没 issue #123 的质押
dcallocator.slash(123);
```

## 部署参数

部署合约时需要提供以下参数：

1. `_multiSigCommittee`: 初始委员会成员地址数组
2. `_threshold`: 罚没阈值
3. `_maxCommitteeSize`: 委员会最大人数
4. `_vault`: 保险库地址
5. `_challengePeriod`: 挑战期时长（单位：天）

## 注意事项

1. 质押后需等待挑战期（默认180天）才能取回质押
2. 每个 issue 只能被质押一次，但可以通过 `stakeMore` 函数增加质押金额
3. 增加质押金额会重置质押时间
4. 委员会成员对同一 issue 只能提交一次罚没提议
5. 当罚没提议达到阈值时，质押将被罚没并转移到保险库
6. 被罚没的质押无法取回