// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Ownable.sol";

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
    // 委员会最大人数
    uint256 public maxCommitteeSize;

    // 事件
    event CommitteeMemberAdded(address indexed member, uint256 newTotal);
    event CommitteeMemberRemoved(address indexed member, uint256 newTotal);
    event ThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event MaxCommitteeSizeUpdated(uint256 oldSize, uint256 newSize);

    /**
     * @dev 构造函数
     * @param _multiSigCommittee 初始委员会成员数组
     * @param _threshold 阈值
     * @param _maxCommitteeSize 最大委员会人数
     */
    constructor(
        address[] memory _multiSigCommittee, 
        uint256 _threshold, 
        uint256 _maxCommitteeSize
    ) Ownable() {
        require(_multiSigCommittee.length > 0, "Committee cannot be empty");
        require(_threshold > 0 && _threshold <= _multiSigCommittee.length, "Invalid threshold");
        require(_maxCommitteeSize >= _multiSigCommittee.length, "Max size too small");

        multiSigCommittee = _multiSigCommittee;
        threshold = _threshold;
        committeeTotal = multiSigCommittee.length;
        maxCommitteeSize = _maxCommitteeSize;
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
        require(committeeTotal < maxCommitteeSize, "Committee total cannot exceed maximum size");

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
     * @dev 设置最大委员会人数
     * @param _maxCommitteeSize 新的最大人数
     */
    function setMaxCommitteeSize(uint256 _maxCommitteeSize) public onlyOwner {
        require(_maxCommitteeSize >= committeeTotal, "Max size cannot be less than current total");
        uint256 oldSize = maxCommitteeSize;
        maxCommitteeSize = _maxCommitteeSize;
        emit MaxCommitteeSizeUpdated(oldSize, _maxCommitteeSize);
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