// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//原生token质押到DCAllocator智能合约
//阈值签名可以发起slash某个DC质押的token
//具有slash权限的是多签地址
//没有slash的情况下，质押用户可以unstak自己的token，判断条件：已经过了挑战时间
//slash的会转到另外一个地址

contract DCAllocator{
    //被slash的token会转移到这个地址
    address public vault;
    address[] public multiSigCommittee;
    //委员会阈值人数
    uint public threshold;
    //委员会最大人数
    uint public committeeTotal;

    //默认是合约部署者
    address public owner;
    //挑战期时长,默认180天，单位：day; onwer可以修改
    uint256 public challengePeriod = 180 days;

    //用户质押映射,key:用户地址,value:质押金额和质押时间
    struct Stake { 
        address user;
        uint256 amount;
        uint256 timestamp;
        bool isSlash;
    }
    mapping(uint => Stake) public stakes;
    
    // 跟踪所有活跃的 issue
    uint[] public activeIssues;
    mapping(uint => uint) public issueToIndex; // issue -> index in activeIssues

    //key: issue, value: []address(committee member)
    mapping(uint => address[]) public slashProposals;

    event Staked(uint issue, address indexed user, uint256 amount, uint256 timestamp);
    event Unstaked(uint issue, address indexed user, uint256 amount, uint256 timestamp);
    event Slashed(uint issue, address indexed user, uint256 amount, uint256 timestamp, address[] validProposals);
    event eventAddSlashProposal(uint issue, address indexed user, uint256 amount, uint256 timestamp, address proposer);

    //谁部署的合约，谁就是owner
    constructor(address[] memory _multiSigCommittee, uint256 _threshold, uint256 _committeeTotal) {
        multiSigCommittee = _multiSigCommittee;
        threshold = _threshold;
        committeeTotal = _committeeTotal;

        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    //设置挑战期期时长,单位：day
    function setChallengePeriod(uint256 _challengePeriod) public onlyOwner{
        challengePeriod = _challengePeriod;
    }

    //质押原生代币到一个多签地址
    function stake(uint issue) public payable {
        require(msg.value > 0, "Amount must be greater than 0");
        require(stakes[issue].user == address(0) || stakes[issue].user == msg.sender, 
            "Issue already taken by another user");

        if(stakes[issue].user == address(0)) {
            stakes[issue] = Stake({
                user: msg.sender,
                amount: msg.value,
                timestamp: block.timestamp,
                isSlash: false
            });
            // 添加 issue 到 activeIssues
            activeIssues.push(issue);
            issueToIndex[issue] = activeIssues.length - 1;
        } else {//如果质押到一个已经存在的issue号，但是address不一样，则会更新质押金额和时间
            stakes[issue].amount += msg.value;
            stakes[issue].timestamp = block.timestamp;
        }

        emit Staked(issue, msg.sender, msg.value, block.timestamp);
    }

    //解质押，当质押时间超过challengePeriod，才可以调用此函数
    function unstake(uint issue) public {
        Stake storage userStake = stakes[issue];
        require(userStake.user == msg.sender, "Not the stake owner");
        require(!userStake.isSlash, "Stake has been slashed");
        require(block.timestamp - userStake.timestamp >= challengePeriod, 
            "Challenge period not over");

        uint256 amount = userStake.amount;
        delete stakes[issue]; // 直接删除整个质押记录
        // 移除 issue 从 activeIssues
        uint index = issueToIndex[issue];
        activeIssues[index] = activeIssues[activeIssues.length - 1];
        activeIssues.pop();
        delete issueToIndex[issue];

        payable(msg.sender).transfer(amount);
        emit Unstaked(issue, msg.sender, amount, block.timestamp);
    }

    //slash某个地址的质押金额
    function slash(uint issue) public {
        // 确保调用者是委员会成员
        require(isCommitteeMember(msg.sender), "Not a committee member");
        
        Stake storage targetStake = stakes[issue];
        require(targetStake.user != address(0), "No stake found");
        require(!targetStake.isSlash, "Already slashed");

        // 添加当前调用者的提议
        addSlashProposal(issue);

        // 如果有效提议数量达到阈值，则执行 slash 操作
        if (hasReachedThreshold(issue)) {
            uint256 amount = targetStake.amount;
            targetStake.isSlash = true;
            targetStake.amount = 0;

            if(vault != address(0)) {
                payable(vault).transfer(amount);
            }
            
            // 从 activeIssues 中移除该 issue
            uint index = issueToIndex[issue];
            activeIssues[index] = activeIssues[activeIssues.length - 1];
            issueToIndex[activeIssues[activeIssues.length - 1]] = index;
            activeIssues.pop();
            delete issueToIndex[issue];
            
            // 触发Slashed事件
            emit Slashed(issue, targetStake.user, amount, block.timestamp, slashProposals[issue]);
        }else {
            // 提议不足，返回提示信息
            emit eventAddSlashProposal(issue, targetStake.user, targetStake.amount, block.timestamp, msg.sender);
        }
    }

    //设置vault地址，只有owner可以调用
    function setVault(address _vault) public onlyOwner {
        require(_vault != address(0), "Vault address cannot be zero");
        vault = _vault;
    }

    // 检查地址是否是委员会成员
    function isCommitteeMember(address _address) public view returns (bool) {
        for (uint i = 0; i < committeeTotal; i++) {
            if (multiSigCommittee[i] == _address) {
                return true;
            }
        }
        return false;
    }

    //是否达成阈值
    function hasReachedThreshold(uint issue) public view returns (bool) {
        Stake storage targetStake = stakes[issue];
        return targetStake.amount >= threshold;
    }

    // 委员会成员添加slash提议
    function addSlashProposal(uint issue) internal {
        Stake storage targetStake = stakes[issue];
        require(targetStake.user != address(0), "No stake found");
        require(!targetStake.isSlash, "Already slashed");
        
        // 检查是否已经有该成员的提议
        address[] storage proposals = slashProposals[issue];
        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i] == msg.sender) {
                revert("Member already proposed");
            }
        }
        
        // 添加新提议
        slashProposals[issue].push(msg.sender);
    }

    // 获取某个issue的所有slash提议
    function getSlashProposals(uint issue) public view returns (address[] memory) {
        address[] storage proposals = slashProposals[issue];
        address[] memory proposers = new address[](proposals.length);
        
        for (uint i = 0; i < proposals.length; i++) {
            proposers[i] = proposals[i];
        }
        
        return proposers;
    }

    // 添加委员会成员
    function addCommitteeMember(address _member) public onlyOwner(){
        require(!isCommitteeMember(_member), "Address is already a committee member");

        if (multiSigCommittee.length == committeeTotal) {
            revert("Cannot add more members: committee is full");
        }

        multiSigCommittee.push(_member);
    }
    
    // 移除委员会成员
    function removeCommitteeMember(address _member) public onlyOwner(){
        require(isCommitteeMember(_member), "Address is not a committee member");
        require(committeeTotal > threshold, "Cannot remove member: would make threshold impossible to reach");
        
        // 找到并移除成员
        bool found = false;
        for (uint i = 0; i < multiSigCommittee.length; i++) {
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
    
    // 更新所有 slashProposal，移除指定成员的提议
    function updateSlashProposals(address _member) internal {
        // 这里需要遍历所有的 slashProposal
        // 由于我们现在有一个数组来跟踪所有活跃的 issue
        for (uint i = 0; i < activeIssues.length; i++) {
            uint issue = activeIssues[i];
            address[] storage proposals = slashProposals[issue];
            
            for (uint j = 0; j < proposals.length; j++) {
                if (proposals[j] == _member) {
                    // 将最后一个元素移到当前位置，然后删除最后一个元素
                    proposals[j] = proposals[proposals.length - 1];
                    proposals.pop();
                    break;
                }
            }
        }
    }
    
    // 更新阈值
    function updateThreshold(uint256 _threshold) public onlyOwner{
        require(_threshold > 0, "Threshold must be greater than 0");
        require(_threshold <= committeeTotal, "Threshold cannot exceed committee total");
        
        threshold = _threshold;
    }

    // 获取活跃问题的数量
    function getActiveIssuesCount() public view returns (uint) {
        return activeIssues.length;
    }
}