// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title DCAllocator
 * @dev 一个基于多签委员会的质押与罚没管理合约
 *
 * 合约功能总结：
 * 1. 质押管理：
 *    - 用户可以对特定issue进行ETH质押
 *    - 每个issue只能被质押一次，不支持在初始质押时追加
 *    - 用户可以通过stakeMore函数增加对已有issue的质押金额，同时会重置质押时间
 *    - 质押后需等待挑战期(默认180天)才能取回质押
 *
 * 2. 委员会管理：
 *    - 合约由多签委员会成员共同管理
 *    - 委员会成员可以对质押提出罚没提议
 *    - 当罚没提议达到阈值时，质押将被罚没并转移到保险库
 *    - 合约拥有者可以添加或移除委员会成员
 *    - 委员会成员数量有上限(maxCommitteeSize)
 *
 * 3. 罚没机制：
 *    - 委员会成员可以对质押发起罚没提议
 *    - 当提议数量达到阈值时，质押将被罚没
 *    - 被罚没的资金将转移到指定的保险库地址
 *
 * 4. 活跃问题管理：
 *    - 合约维护一个活跃问题列表
 *    - 当质押被取回或罚没时，相应的问题将从活跃列表中移除
 *
 * 安全特性：
 * - 只有合约拥有者可以修改关键参数(挑战期、保险库地址)
 * - 只有合约拥有者可以管理委员会成员
 * - 委员会成员数量不能低于阈值，确保多签机制正常运行
 * - 每个委员会成员对同一issue只能提交一次罚没提议
 */

// 原生token质押到DCAllocator智能合约
// 质押后需要等待一定时间才能取回
// 如果在质押期间，委员会成员达到一定阈值认为该质押应该被slash的会转到另外一个地址

contract DCAllocator {
    // 质押结构体，用于存储用户的质押信息
    struct Stake {
        address user; // 质押用户地址
        uint256 amount; // 质押金额
        uint256 timestamp; // 质押时间戳
        bool isSlash; // 是否已被罚没
    }
    // 被slash的token会转移到这个地址

    address public vault;
    // 委员会成员地址数组，负责投票决定是否罚没质押
    address[] public multiSigCommittee;
    // 阈值，决定多少委员会成员同意后才能执行罚没操作
    uint256 public threshold;
    // 委员会总人数，用于跟踪当前委员会的规模
    uint256 public committeeTotal;

    // 委员会最大人数
    uint256 public maxCommitteeSize;

    // 合约拥有者地址，默认为部署合约的地址
    address public owner;
    // 挑战期，默认为180天，用户必须等待这段时间后才能取回质押
    uint256 public challengePeriod = 180 days;
    // 质押映射，issue ID => Stake结构体
    mapping(uint256 => Stake) public stakes;
    // 跟踪所有活跃的 issue
    uint256[] public activeIssues;
    // issue ID到数组索引的映射，用于O(1)时间复杂度查找和删除
    // 记录每个issue在activeIssues数组中的位置
    mapping(uint256 => uint256) public issueToIndex; // issue -> index in activeIssues
    // 罚没提议映射，issue ID => 提议者地址数组
    // 记录每个issue的所有罚没提议及提议者
    mapping(uint256 => address[]) public slashProposals;

    // 质押事件，当用户进行质押时触发
    event Staked(uint256 issue, address indexed user, uint256 amount, uint256 timestamp);
    // 取回质押事件，当用户成功取回质押时触发
    event Unstaked(uint256 issue, address indexed user, uint256 amount, uint256 timestamp);
    // 罚没事件，当质押被成功罚没时触发，包含所有投票的委员会成员
    event Slashed(uint256 issue, address indexed user, uint256 amount, uint256 timestamp, address[] committeeMembers);
    // 添加罚没提议事件，当委员会成员添加罚没提议但未达到阈值时触发
    event eventAddSlashProposal(
        uint256 issue, address indexed user, uint256 amount, uint256 timestamp, address proposer
    );
    // 增加质押金额事件，当用户对已有质押增加金额时触发
    event StakedMore(
        uint256 issue, address indexed user, uint256 additionalAmount, uint256 newAmount, uint256 timestamp
    );

    // 构造函数，初始化合约的基本参数
    constructor(
        address[] memory _multiSigCommittee, 
        uint256 _threshold, 
        uint256 _maxCommitteeSize,
        address _vault,
        uint256 _challengePeriod
    ) {
        multiSigCommittee = _multiSigCommittee;
        threshold = _threshold;
        committeeTotal = multiSigCommittee.length;
        maxCommitteeSize = _maxCommitteeSize;
        
        // 直接设置保险库地址和挑战期
        vault = _vault;
        if (_challengePeriod > 0) {
            challengePeriod = _challengePeriod * 1 days;
        }

        owner = msg.sender;
    }

    // 仅合约拥有者可调用的修饰符
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // 仅委员会成员可调用的修饰符
    modifier onlyCommittee() {
        bool isCommittee = false;
        for (uint256 i = 0; i < multiSigCommittee.length; i++) {
            if (multiSigCommittee[i] == msg.sender) {
                isCommittee = true;
                break;
            }
        }
        require(isCommittee, "Only committee members can call this function");
        _;
    }

    // 设置挑战期期时长，单位：天
    // 只有合约拥有者可以调用
    function setChallengePeriod(uint256 _challengePeriod) public onlyOwner {
        challengePeriod = _challengePeriod;
    }

    // 质押函数，用户通过发送ETH来质押特定issue
    // 每个issue只能被质押一次
    function stake(uint256 issue) public payable {
        require(msg.value > 0, "Amount must be greater than 0");
        require(stakes[issue].user == address(0), "Issue already staked");

        // 创建质押记录
        stakes[issue] = Stake({user: msg.sender, amount: msg.value, timestamp: block.timestamp, isSlash: false});

        // 添加到活跃问题列表
        issueToIndex[issue] = activeIssues.length;
        activeIssues.push(issue);

        emit Staked(issue, msg.sender, msg.value, block.timestamp);
    }

    // 增加质押金额函数，用户可以增加对已有issue的质押金额
    function stakeMore(uint256 issue) public payable {
        Stake storage targetStake = stakes[issue];
        require(targetStake.user == msg.sender, "Not the staker");
        require(!targetStake.isSlash, "Stake has been slashed");
        require(msg.value > 0, "Amount must be greater than 0");

        uint256 additionalAmount = msg.value;
        uint256 newAmount = targetStake.amount + additionalAmount;
        targetStake.amount = newAmount;
        targetStake.timestamp = block.timestamp; // 更新质押时间戳

        emit StakedMore(issue, msg.sender, additionalAmount, newAmount, block.timestamp);
    }

    // 取回质押函数，当质押时间超过挑战期后，用户可以取回质押
    function unstake(uint256 issue) public {
        Stake storage targetStake = stakes[issue];
        require(targetStake.user == msg.sender, "Not the staker");
        require(!targetStake.isSlash, "Stake has been slashed");
        require(block.timestamp > targetStake.timestamp + challengePeriod, "Challenge period not over");

        uint256 amount = targetStake.amount;
        targetStake.amount = 0;
        targetStake.user = address(0);

        // 从activeIssues中移除
        removeActiveIssue(issue);

        payable(msg.sender).transfer(amount);
        emit Unstaked(issue, msg.sender, amount, block.timestamp);
    }

    // 罚没函数，委员会成员可以调用此函数来提议罚没特定issue的质押
    function slash(uint256 issue) public onlyCommittee {
        // 确保质押存在
        Stake storage targetStake = stakes[issue];
        require(targetStake.user != address(0), "No stake found");
        require(!targetStake.isSlash, "Already slashed");

        // 添加slash提议
        addSlashProposal(issue);
        emit eventAddSlashProposal(issue, targetStake.user, targetStake.amount, targetStake.timestamp, msg.sender);

        // 检查是否达到阈值
        if (hasReachedThreshold(issue)) {
            // 达到阈值，执行slash
            targetStake.isSlash = true;
            uint256 amount = targetStake.amount;
            targetStake.amount = 0;

            // 从activeIssues中移除
            removeActiveIssue(issue);

            // 将资金转移到保险库
            payable(vault).transfer(amount);

            // 获取所有有效的提议
            address[] memory validProposals = getSlashProposals(issue);

            emit Slashed(issue, targetStake.user, amount, block.timestamp, validProposals);
        }
    }

    // 设置保险库地址，只有合约拥有者可以调用
    function setVault(address _vault) public onlyOwner {
        require(_vault != address(0), "Vault address cannot be zero");
        vault = _vault;
    }

    // 检查地址是否是委员会成员
    function isCommitteeMember(address _address) public view returns (bool) {
        for (uint256 i = 0; i < committeeTotal; i++) {
            if (multiSigCommittee[i] == _address) {
                return true;
            }
        }
        return false;
    }

    // 检查某个issue的罚没提议是否达到阈值
    function hasReachedThreshold(uint256 issue) public view returns (bool) {
        address[] storage proposals = slashProposals[issue];
        return proposals.length >= threshold;
    }

    // 委员会成员添加罚没提议的内部函数
    function addSlashProposal(uint256 issue) internal {
        Stake storage targetStake = stakes[issue];
        require(targetStake.user != address(0), "No stake found");
        require(!targetStake.isSlash, "Already slashed");

        // 检查是否已经有该成员的提议
        address[] storage proposals = slashProposals[issue];
        for (uint256 i = 0; i < proposals.length; i++) {
            if (proposals[i] == msg.sender) {
                revert("Member already proposed");
            }
        }

        // 添加新提议
        slashProposals[issue].push(msg.sender);
    }

    // 获取某个issue的所有罚没提议
    function getSlashProposals(uint256 issue) public view returns (address[] memory) {
        address[] storage proposals = slashProposals[issue];
        address[] memory proposers = new address[](proposals.length);

        for (uint256 i = 0; i < proposals.length; i++) {
            proposers[i] = proposals[i];
        }

        return proposers;
    }

    // 添加委员会成员，只有合约拥有者可以调用
    function addCommitteeMember(address _member) public onlyOwner {
        require(!isCommitteeMember(_member), "Address is already a committee member");
        require(committeeTotal < maxCommitteeSize, "Committee total cannot exceed maximum size");

        multiSigCommittee.push(_member);
        committeeTotal++;
    }

    // 移除委员会成员，只有合约拥有者可以调用
    function removeCommitteeMember(address _member) public onlyOwner {
        require(isCommitteeMember(_member), "Address is not a committee member");
        require(committeeTotal > threshold, "Cannot remove member: would make threshold impossible to reach");

        // 找到并移除成员
        bool found = false;
        for (uint256 i = 0; i < multiSigCommittee.length; i++) {
            if (multiSigCommittee[i] == _member) {
                // 将最后一个元素移到当前位置，然后删除最后一个元素
                multiSigCommittee[i] = multiSigCommittee[multiSigCommittee.length - 1];
                multiSigCommittee.pop();
                found = true;
                committeeTotal--;
                break;
            }
        }

        require(found, "Failed to remove member");

        // 更新所有 slashProposal，移除该成员的提议
        updateSlashProposals(_member);
    }

    // 更新所有罚没提议，移除指定成员的提议
    function updateSlashProposals(address _member) internal {
        // 遍历所有活跃的issue，移除指定成员的提议
        for (uint256 i = 0; i < activeIssues.length; i++) {
            uint256 issue = activeIssues[i];
            address[] storage proposals = slashProposals[issue];

            for (uint256 j = 0; j < proposals.length; j++) {
                if (proposals[j] == _member) {
                    // 将最后一个元素移到当前位置，然后删除最后一个元素
                    proposals[j] = proposals[proposals.length - 1];
                    proposals.pop();
                    break;
                }
            }
        }
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
}
