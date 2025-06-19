// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MultiSigCommittee
 * @dev 多重签名委员会管理基类
 * 
 * 功能包括：
 * - 委员会成员管理（添加/移除成员）
 * - 成员身份验证
 * - 阈值管理
 * - 委员会大小限制
 */
contract MultiSigCommittee is Ownable {
    // 委员会成员地址数组
    address[] public multiSigCommittee;
    // 阈值，决定多少委员会成员同意后才能执行操作
    uint256 public threshold;
    // 委员会总人数，用于跟踪当前委员会的规模
    uint256 public committeeTotal;

    // 事件
    event CommitteeMemberAdded(address indexed member, uint256 newTotal);
    event CommitteeMemberRemoved(address indexed member, uint256 newTotal);
    event ThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    /**
     * @dev 构造函数
     * @param _threshold 阈值
     */
    constructor(
        uint256 _threshold
    ) Ownable(msg.sender) {
        require(_threshold > 0, "Invalid threshold");
        threshold = _threshold;
        committeeTotal = 0;
    }

    // 仅委员会成员可调用的修饰符
    modifier onlyCommittee() {
        require(isCommitteeMember(msg.sender), "Only committee members can call this function");
        _;
    }

    /**
     * @dev 检查地址是否是委员会成员
     * @param _address 要检查的地址
     * @return 是否是委员会成员
     */
    function isCommitteeMember(address _address) public view returns (bool) {
        for (uint256 i = 0; i < committeeTotal; i++) {
            if (multiSigCommittee[i] == _address) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev 获取委员会成员列表
     * @return 委员会成员地址数组
     */
    function getCommitteeMembers() public view returns (address[] memory) {
        address[] memory members = new address[](committeeTotal);
        for (uint256 i = 0; i < committeeTotal; i++) {
            members[i] = multiSigCommittee[i];
        }
        return members;
    }

    /**
     * @dev 添加委员会成员
     * @param _member 要添加的成员地址
     */
    function addCommitteeMember(address _member) public onlyOwner {
        require(_member != address(0), "Invalid member address");
        require(!isCommitteeMember(_member), "Address is already a committee member");

        multiSigCommittee.push(_member);
        committeeTotal++;

        emit CommitteeMemberAdded(_member, committeeTotal);
    }

    /**
     * @dev 移除委员会成员
     * @param _member 要移除的成员地址
     */
    function removeCommitteeMember(address _member) public virtual onlyOwner {
        require(isCommitteeMember(_member), "Address is not a committee member");
        require(committeeTotal - 1 >= threshold, "Cannot remove member: would make threshold impossible to reach");

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

        emit CommitteeMemberRemoved(_member, committeeTotal);
    }

    /**
     * @dev 设置阈值
     * @param _threshold 新的阈值
     */
    function setThreshold(uint256 _threshold) public onlyOwner {
        require(_threshold > 0 && _threshold <= committeeTotal, "Invalid threshold");
        uint256 oldThreshold = threshold;
        threshold = _threshold;
        emit ThresholdUpdated(oldThreshold, _threshold);
    }

    /**
     * @dev 检查提议数量是否达到阈值
     * @param proposalCount 提议数量
     * @return 是否达到阈值
     */
    function hasReachedThreshold(uint256 proposalCount) public view returns (bool) {
        return proposalCount >= threshold;
    }
} 