# DCAllocator 接口文档

## 目录

- [概述](#概述)
- [合约地址](#合约地址)
- [合约功能](#合约功能)
  - [1. 质押管理](#1-质押管理)
    - [1.1 质押 (stake)](#11-质押-stake)
    - [1.2 增加质押金额 (stakeMore)](#12-增加质押金额-stakemore)
    - [1.3 取回质押 (unstake)](#13-取回质押-unstake)
  - [2. 罚没机制](#2-罚没机制)
    - [2.1 直接罚没 (slash)](#21-直接罚没-slash)
  - [3. 合约配置](#3-合约配置)
    - [3.1 设置挑战期 (setChallengePeriod)](#31-设置挑战期-setchallengeperiod)
    - [3.2 设置保险库地址 (setVault)](#32-设置保险库地址-setvault)
    - [3.3 设置多签地址 (setCommitteeMultisig)](#33-设置多签地址-setcommitteemultisig)
    - [3.4 迁移owner权限 (transferOwnership)](#34-迁移owner权限-transferownership)
  - [4. 查询接口](#4-查询接口)
    - [4.1 获取活跃问题数量 (getActiveIssuesCount)](#41-获取活跃问题数量-getactiveissuescount)
    - [4.2 获取所有活跃质押 (getAllActiveStakes)](#42-获取所有活跃质押-getallactivestakes)
    - [4.3 获取所有历史质押 (getAllStakes)](#43-获取所有历史质押-getallstakes)
    - [4.4 分页获取历史质押 (getAllStakesPaged)](#44-分页获取历史质押-getallstakespaged)
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
  - [直接罚没](#直接罚没)
- [部署参数](#部署参数)
- [注意事项](#注意事项)

## 概述

DCAllocator 是一个基于多签地址的质押与罚没管理智能合约，用于管理用户对特定 issue 的 FIL 质押。合约支持质押管理、多签地址管理、罚没机制和活跃/历史质押管理等功能。

## 合约地址

（请替换为实际部署地址）

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
- 质押金额必须大于等于 0.0001 ETH
- 不能超过 100 ETH
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
- 增加的金额必须大于等于 0.0001 ETH，且不超过 100 ETH

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

### 2. 罚没机制

#### 2.1 直接罚没 (slash)

只有多签地址（committeeMultisig）可以直接对质押执行罚没。

**函数签名:**
```solidity
function slash(uint256 issue, string memory reason) public
```

**参数:**
- `issue`: 要罚没的 issue 标识符
- `reason`: 罚没理由

**要求:**
- 调用者必须是 committeeMultisig
- 指定的 issue 必须已被质押且未被罚没

**事件:**
- `Slashed(uint256 issue, address indexed user, uint256 amount, uint256 timestamp, address committeeMultisig, string reason)`

### 3. 合约配置

#### 3.1 设置挑战期 (setChallengePeriod)

**函数签名:**
```solidity
function setChallengePeriod(uint256 _challengePeriod) public onlyOwner
```

**参数:**
- `_challengePeriod`: 新的挑战期时长（单位：天）

#### 3.2 设置保险库地址 (setVault)

**函数签名:**
```solidity
function setVault(address _vault) public onlyOwner
```

**参数:**
- `_vault`: 新的保险库地址

**要求:**
- 新地址不能为零地址

#### 3.3 设置多签地址 (setCommitteeMultisig)

**函数签名:**
```solidity
function setCommitteeMultisig(address _committeeMultisig) public onlyOwner
```

**参数:**
- `_committeeMultisig`: 新的多签地址

**要求:**
- 新地址不能为零地址

#### 3.4 迁移owner权限 (transferOwnership)

**函数签名:**
```solidity
function transferOwnership(address newOwner) public onlyOwner
```

**参数:**
- `newOwner`: 新的owner地址，不能为零地址

**说明:**
- 只有当前owner可调用，迁移后只有新owner可再管理合约

### 4. 查询接口

#### 4.1 获取活跃问题数量 (getActiveIssuesCount)

**函数签名:**
```solidity
function getActiveIssuesCount() public view returns (uint256)
```

**返回值:**
- `uint256`: 活跃问题的数量

#### 4.2 获取所有活跃质押 (getAllActiveStakes)

**函数签名:**
```solidity
function getAllActiveStakes() public view returns (Stake[] memory)
```

**返回值:**
- `Stake[]`: 当前所有活跃质押的详细信息

#### 4.3 获取所有历史质押 (getAllStakes)

**函数签名:**
```solidity
function getAllStakes() public view returns (Stake[] memory)
```

**返回值:**
- `Stake[]`: 所有历史质押（包括已结束和被罚没）的详细信息

#### 4.4 分页获取历史质押 (getAllStakesPaged)

**函数签名:**
```solidity
function getAllStakesPaged(uint256 offset, uint256 limit) public view returns (Stake[] memory)
```

**参数:**
- `offset`: 起始下标
- `limit`: 返回数量

**返回值:**
- `Stake[]`: 指定区间的历史质押信息

## 状态变量

### 公共变量

- `vault`: 保险库地址，被罚没的资金将转移到此地址
- `committeeMultisig`: 多签地址，只有该地址可以执行罚没
- `owner`: 合约拥有者地址
- `challengePeriod`: 挑战期时长，默认为180天
- `activeIssues`: 活跃问题列表
- `allIssues`: 所有出现过的 issue 列表
- `stakes`: issue ID => Stake 结构体，存储质押信息
- `issueToIndex`: issue ID => 数组索引，用于快速查找和删除活跃问题

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
- `Slashed(uint256 issue, address indexed user, uint256 amount, uint256 timestamp, address committeeMultisig, string reason)`: 罚没事件
- `StakedMore(uint256 issue, address indexed user, uint256 additionalAmount, uint256 newAmount, uint256 timestamp)`: 增加质押金额事件

## 安全特性

- 只有合约拥有者可以修改关键参数（挑战期、保险库地址、多签地址）
- 只有多签地址可以执行罚没
- 质押后需等待挑战期才能取回质押
- 被罚没的资金将转移到指定的保险库地址
- 使用重入锁防止重入攻击
- owner权限可通过transferOwnership(address newOwner)迁移，迁移后只有新owner可再管理合约

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

### 直接罚没

```solidity
// 多签地址直接罚没 issue #123 的质押
dcallocator.slash(123, "违规原因");
```

## 部署参数

部署合约时需要提供以下参数：

1. `_vault`: 保险库地址
2. `_challengePeriod`: 挑战期时长（单位：天）
3. `_committeeMultisig`: 多签地址

## 注意事项

1. 质押后需等待挑战期（默认180天）才能取回质押
2. 每个 issue 只能被质押一次，但可以通过 `stakeMore` 函数增加质押金额
3. 增加质押金额会重置质押时间
4. 只有多签地址可以直接罚没质押
5. 被罚没的质押无法取回
6. 建议分页查询历史质押，避免gas超限