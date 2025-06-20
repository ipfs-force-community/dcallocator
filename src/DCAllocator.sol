// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DCAllocator
 * @dev 一个基于委员会多签地址的质押与罚没管理合约
 *
 * 合约功能总结：
 * 1. 质押管理：
 *    - 用户可以对特定issue进行FIL质押
 *    - 每个issue只能被质押一次，不支持在初始质押时追加
 *    - 用户可以通过stakeMore函数增加对已有issue的质押金额，同时会重置质押时间
 *    - 质押后需等待挑战期(默认180天)才能取回质押
 *
 * 2. 委员会多签地址管理：
 *    - 合约拥有一个委员会多签地址（committeeMultisig），只有该地址可以执行罚没操作
 *    - 合约拥有者可以设置或更换委员会多签地址
 *
 * 3. 罚没机制：
 *    - 只有委员会多签地址可以对质押执行罚没（slash）
 *    - 被罚没的资金将转移到指定的保险库地址
 *
 * 4. 活跃问题管理：
 *    - 合约维护一个活跃问题列表
 *    - 当质押被取回或罚没时，相应的问题将从活跃列表中移除
 *
 * 安全特性：
 * - 只有合约拥有者可以修改关键参数(挑战期、保险库地址、委员会多签地址)
 * - 使用重入锁防止重入攻击
 */

// 原生token质押到DCAllocator智能合约
// 质押后需要等待一定时间才能取回
// 如果在质押期间，委员会成员达到一定阈值认为该质押应该被slash的会转到另外一个地址

contract DCAllocator is ReentrancyGuard, Ownable {
    // 质押结构体，用于存储用户的质押信息
    struct Stake {
        address user; // 质押用户地址
        uint256 amount; // 质押金额
        uint256 timestamp; // 质押时间戳
        bool isSlash; // 是否已被罚没
    }

    // 被slash的token会转移到这个地址
    address public vault;

    // 挑战期，默认为180天，用户必须等待这段时间后才能取回质押
    uint256 public challengePeriod = 180 days;

    // 质押映射，issue ID => Stake结构体
    mapping(uint256 => Stake) public stakes;

    // 跟踪所有活跃的 issue
    uint256[] public activeIssues;

    // 新增：跟踪所有出现过的 issue
    uint256[] public allIssues;

    // issue ID到数组索引的映射，用于O(1)时间复杂度查找和删除
    // 记录每个issue在activeIssues数组中的位置
    mapping(uint256 => uint256) public issueToIndex; // issue -> index in activeIssues

    // 委员会多签地址（只有该地址可以执行slash操作）
    address public committeeMultisig;

    // 质押事件，当用户进行质押时触发
    event Staked(uint256 issue, address indexed user, uint256 amount, uint256 timestamp);
    // 取回质押事件，当用户成功取回质押时触发
    event Unstaked(uint256 issue, address indexed user, uint256 amount, uint256 timestamp);
    // 罚没事件，当质押被成功罚没时触发，记录委员会多签地址和处罚理由
    event Slashed(
        uint256 issue, address indexed user, uint256 amount, uint256 timestamp, address committeeMultisig, string reason
    );
    // 增加质押金额事件，当用户对已有质押增加金额时触发
    event StakedMore(
        uint256 issue, address indexed user, uint256 additionalAmount, uint256 newAmount, uint256 timestamp
    );

    uint256 public constant MIN_STAKE = 0.0001 ether;
    uint256 public constant MAX_STAKE = 100 ether;

    // 构造函数，初始化合约的基本参数
    constructor(address _vault, uint256 _challengePeriod, address _committeeMultisig) Ownable(msg.sender) {
        // 直接设置保险库地址和挑战期
        vault = _vault;
        if (_challengePeriod > 0) {
            challengePeriod = _challengePeriod * 1 days;
        }
        committeeMultisig = _committeeMultisig;
    }

    // 设置挑战期期时长，单位：天
    // 只有合约拥有者可以调用
    function setChallengePeriod(uint256 _challengePeriod) public onlyOwner {
        challengePeriod = _challengePeriod;
    }

    // 设置保险库地址，只有合约拥有者可以调用
    function setVault(address _vault) public onlyOwner {
        require(_vault != address(0), "Vault address cannot be zero");
        vault = _vault;
    }

    // 新增设置委员会多签地址的方法
    function setCommitteeMultisig(address _committeeMultisig) public onlyOwner {
        require(_committeeMultisig != address(0), "Committee multisig address cannot be zero");
        committeeMultisig = _committeeMultisig;
    }

    // 质押函数，用户通过发送ETH来质押特定issue
    // 每个issue只能被质押一次
    function stake(uint256 issue) public payable {
        require(msg.value >= MIN_STAKE, "Amount must be >= 0.0001 ETH");
        require(msg.value <= MAX_STAKE, "Amount must be <= 100 ETH");
        require(stakes[issue].user == address(0), "Issue already staked");

        // 创建质押记录
        stakes[issue] = Stake({user: msg.sender, amount: msg.value, timestamp: block.timestamp, isSlash: false});

        // 添加到活跃问题列表
        issueToIndex[issue] = activeIssues.length;
        activeIssues.push(issue);
        // 新增：添加到所有问题列表
        allIssues.push(issue);

        emit Staked(issue, msg.sender, msg.value, block.timestamp);
    }

    // 增加质押金额函数，用户可以增加对已有issue的质押金额
    function stakeMore(uint256 issue) public payable {
        Stake storage targetStake = stakes[issue];
        require(targetStake.user == msg.sender, "Not the staker");
        require(!targetStake.isSlash, "Stake has been slashed");
        require(msg.value >= MIN_STAKE, "Amount must be >= 0.0001 ETH");
        require(msg.value <= MAX_STAKE, "Amount must be <= 100 ETH");

        uint256 additionalAmount = msg.value;
        uint256 newAmount = targetStake.amount + additionalAmount;
        targetStake.amount = newAmount;
        targetStake.timestamp = block.timestamp; // 更新质押时间戳

        emit StakedMore(issue, msg.sender, additionalAmount, newAmount, block.timestamp);
    }

    // 取回质押函数，当质押时间超过挑战期后，用户可以取回质押
    function unstake(uint256 issue) public nonReentrant {
        Stake storage targetStake = stakes[issue];
        require(targetStake.user == msg.sender, "Not the staker");
        require(!targetStake.isSlash, "Stake has been slashed");
        require(block.timestamp > targetStake.timestamp + challengePeriod, "Challenge period not over");

        uint256 amount = targetStake.amount;

        // 先更新状态
        targetStake.amount = 0;
        targetStake.user = address(0);
        removeActiveIssue(issue);

        // 最后进行外部调用
        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit Unstaked(issue, msg.sender, amount, block.timestamp);
    }

    // 只允许委员会多签地址直接执行罚没
    function slash(uint256 issue, string memory reason) public nonReentrant {
        require(msg.sender == committeeMultisig, "Only committee multisig can slash");
        Stake storage targetStake = stakes[issue];
        require(targetStake.user != address(0), "No stake found");
        require(!targetStake.isSlash, "Already slashed");

        uint256 amount = targetStake.amount;
        targetStake.isSlash = true;
        targetStake.amount = 0;
        removeActiveIssue(issue);

        // 直接转账到保险库
        (bool success,) = payable(vault).call{value: amount}("");
        require(success, "Transfer failed");

        emit Slashed(issue, targetStake.user, amount, block.timestamp, committeeMultisig, reason);
    }

    // 获取活跃问题的数量
    function getActiveIssuesCount() public view returns (uint256) {
        return activeIssues.length;
    }

    // 从活跃问题列表中移除指定issue的内部函数
    function removeActiveIssue(uint256 issue) internal {
        uint256 index = issueToIndex[issue];
        activeIssues[index] = activeIssues[activeIssues.length - 1];
        issueToIndex[activeIssues[activeIssues.length - 1]] = index;
        activeIssues.pop();
        delete issueToIndex[issue];
    }

    // 获取所有活跃质押的详细信息
    function getAllActiveStakes() public view returns (Stake[] memory) {
        uint256 count = activeIssues.length;
        Stake[] memory stakesList = new Stake[](count);
        for (uint256 i = 0; i < count; i++) {
            stakesList[i] = stakes[activeIssues[i]];
        }
        return stakesList;
    }

    // 获取所有历史质押（包括已结束和被罚没）的详细信息
    function getAllStakes() public view returns (Stake[] memory) {
        uint256 count = allIssues.length;
        Stake[] memory stakesList = new Stake[](count);
        for (uint256 i = 0; i < count; i++) {
            stakesList[i] = stakes[allIssues[i]];
        }
        return stakesList;
    }

    // 分页获取所有历史质押（包括已结束和被罚没）的详细信息
    function getAllStakesPaged(uint256 offset, uint256 limit) public view returns (Stake[] memory) {
        uint256 total = allIssues.length;
        if (offset >= total) {
            return new Stake[](0);
        }
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        uint256 resultLen = end - offset;
        Stake[] memory stakesList = new Stake[](resultLen);
        for (uint256 i = 0; i < resultLen; i++) {
            stakesList[i] = stakes[allIssues[offset + i]];
        }
        return stakesList;
    }
}
