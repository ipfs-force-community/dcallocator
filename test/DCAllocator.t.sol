// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DCAllocator} from "../src/DCAllocator.sol";

contract DCAllocatorTest is Test {
    DCAllocator public dcAllocator;
    address[] public committee;
    uint256 public threshold;
    uint256 public committeeTotal;
    
    // 测试账户
    address public owner;
    address public user1;
    address public user2;
    address public committeeMember1;
    address public committeeMember2;
    address public committeeMember3;
    address public vault;

    function setUp() public {
        // 设置测试账户
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        committeeMember1 = address(0x3);
        committeeMember2 = address(0x4);
        committeeMember3 = address(0x5);
        vault = address(0x6);
        
        // 设置委员会
        committee = new address[](3);
        committee[0] = committeeMember1;
        committee[1] = committeeMember2;
        committee[2] = committeeMember3;
        
        threshold = 2;
        committeeTotal = 3;
        
        // 部署合约
        dcAllocator = new DCAllocator(committee, threshold, committeeTotal);
        
        // 设置保险库
        dcAllocator.setVault(vault);
    }

    function test_Stake() public {
        // 用户1质押
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        dcAllocator.stake{value: 1 ether}(1);
        
        // 验证质押是否成功
        (address stakeUser, uint256 amount, , bool isSlash) = dcAllocator.stakes(1);
        assertEq(stakeUser, user1);
        assertEq(amount, 1 ether);
        assertFalse(isSlash);
        
        // 验证 activeIssues 是否正确更新
        assertEq(dcAllocator.activeIssues(0), 1);
    }
    
    function test_Unstake() public {
        // 用户1质押
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        dcAllocator.stake{value: 1 ether}(1);
        
        // 快进时间超过挑战期
        vm.warp(block.timestamp + 180 days + 1);
        
        // 用户1取回质押
        vm.prank(user1);
        dcAllocator.unstake(1);
        
        // 验证质押是否已取回
        (address stakeUser, uint256 amount, ,) = dcAllocator.stakes(1);
        assertEq(stakeUser, address(0));
        assertEq(amount, 0);
        
        // 验证 activeIssues 是否为空
        assertEq(dcAllocator.getActiveIssuesCount(), 0);
    }
    
    function test_Slash() public {
        // 用户1质押
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        dcAllocator.stake{value: 1 ether}(1);
        
        // 委员会成员1提议slash
        vm.prank(committeeMember1);
        dcAllocator.slash(1);
        
        // 验证提议是否已添加
        address[] memory proposals = dcAllocator.getSlashProposals(1);
        assertEq(proposals.length, 1);
        assertEq(proposals[0], committeeMember1);
        
        // 委员会成员2提议slash，达到阈值
        vm.prank(committeeMember2);
        dcAllocator.slash(1);
        
        // 验证质押是否已被slash
        (address stakeUser, uint256 amount, , bool isSlash) = dcAllocator.stakes(1);
        assertEq(stakeUser, user1);
        assertEq(amount, 0);
        assertTrue(isSlash);
        
        // 验证资金是否已转移到保险库
        assertEq(vault.balance, 1 ether);
        
        // 验证 activeIssues 是否为空
        assertEq(dcAllocator.getActiveIssuesCount(), 0);
    }
    
    function test_AddCommitteeMember() public {
        address newMember = address(0x7);
        
        // 添加新委员会成员
        dcAllocator.addCommitteeMember(newMember);
        
        // 验证新成员是否已添加
        assertTrue(dcAllocator.isCommitteeMember(newMember));
        assertEq(dcAllocator.committeeTotal(), 4);
    }
    
    function test_RemoveCommitteeMember() public {
        // 移除委员会成员
        dcAllocator.removeCommitteeMember(committeeMember3);
        
        // 验证成员是否已移除
        assertFalse(dcAllocator.isCommitteeMember(committeeMember3));
        assertEq(dcAllocator.committeeTotal(), 2);
        
        // 测试提议更新
        // 先添加一个质押
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        dcAllocator.stake{value: 1 ether}(1);
        
        // 委员会成员3提议slash
        vm.prank(committeeMember3);
        dcAllocator.slash(1);
        
        // 验证提议是否已添加
        address[] memory proposals = dcAllocator.getSlashProposals(1);
        assertEq(proposals.length, 1);
        
        // 移除委员会成员3
        dcAllocator.removeCommitteeMember(committeeMember3);
        
        // 验证提议是否已更新
        proposals = dcAllocator.getSlashProposals(1);
        assertEq(proposals.length, 0);
    }
    
    function test_UpdateThreshold() public {
        // 更新阈值
        dcAllocator.updateThreshold(1);
        
        // 验证阈值是否已更新
        assertEq(dcAllocator.threshold(), 1);
    }
    
    function test_SetVault() public {
        address newVault = address(0x8);
        
        // 设置新的保险库
        dcAllocator.setVault(newVault);
        
        // 验证保险库是否已更新
        assertEq(dcAllocator.vault(), newVault);
    }
}
