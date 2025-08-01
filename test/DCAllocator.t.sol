// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DCAllocator} from "../src/DCAllocator.sol";

contract DCAllocatorTest is Test {
    DCAllocator public dcAllocator;
    // 无委员会相关变量

    // 测试账户
    address public owner;
    address public user1;
    address public user2;
    address public vault;

    function setUp() public {
        // 设置测试账户
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        vault = address(0x6);

        // 部署合约
        address multisig = address(0x7);
        dcAllocator = new DCAllocator(vault, 180, multisig);

        // 设置保险库
        dcAllocator.setVault(vault);
    }

    function test_Stake() public {
        // 用户1质押
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        dcAllocator.stake{value: 1 ether}(1);

        // 验证质押是否成功
        (address stakeUser, uint256 amount,, bool isSlash) = dcAllocator.stakes(1);
        assertEq(stakeUser, user1);
        assertEq(amount, 1 ether);
        assertFalse(isSlash);

        // 验证 activeIssues 是否正确更新
        DCAllocator.Stake[] memory actives = dcAllocator.getAllActiveStakes();
        assertEq(actives.length, 1);
        assertEq(actives[0].user, user1);
    }

    function test_Unstake() public {
        // 用户1质押
        address payable user = payable(makeAddr("user"));
        vm.deal(user, 1 ether);
        vm.prank(user);
        dcAllocator.stake{value: 1 ether}(1);

        // 获取当前时间戳
        uint256 currentTimestamp = block.timestamp;

        // 快进时间超过挑战期
        vm.warp(currentTimestamp + 180 days + 1);

        // 用户1取回质押
        vm.prank(user);
        dcAllocator.unstake(1);

        // 验证质押是否已取回
        (address stakeUser, uint256 amount,,) = dcAllocator.stakes(1);
        assertEq(stakeUser, address(0));
        assertEq(amount, 0);

        // 验证 activeIssues 是否为空
        assertEq(dcAllocator.getActiveIssuesCount(), 0);

        // 验证用户余额是否增加
        assertEq(user.balance, 1 ether);
    }

    function test_Slash() public {
        // 用户1质押
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        dcAllocator.stake{value: 1 ether}(1);

        // 由committeeMultisig地址执行slash
        address multisig = address(0x7);
        vm.prank(multisig);
        dcAllocator.slash(1, "test reason");

        // 验证质押是否已被slash
        (address stakeUser, uint256 amount,, bool isSlash) = dcAllocator.stakes(1);
        assertEq(stakeUser, user1);
        assertEq(amount, 0);
        assertTrue(isSlash);

        // 验证资金是否已转移到保险库
        assertEq(vault.balance, 1 ether);

        // 验证 activeIssues 是否为空
        assertEq(dcAllocator.getActiveIssuesCount(), 0);

        // 非committeeMultisig调用slash应revert
        vm.startPrank(user1);
        vm.expectRevert("Only committee multisig can slash");
        dcAllocator.slash(1, "test reason");
        vm.stopPrank();
    }

    function test_SetVault() public {
        address newVault = address(0x8);

        // 设置新的保险库
        dcAllocator.setVault(newVault);

        // 验证保险库是否已更新
        assertEq(dcAllocator.vault(), newVault);
    }

    function test_StakeMore() public {
        // 用户1初始质押
        vm.deal(user1, 2 ether);
        vm.prank(user1);
        dcAllocator.stake{value: 1 ether}(1);

        // 记录初始质押时间
        (,, uint256 initialTimestamp,) = dcAllocator.stakes(1);

        // 增加时间，模拟经过一段时间
        vm.warp(block.timestamp + 30 days);

        // 用户1增加质押金额
        vm.prank(user1);
        dcAllocator.stakeMore{value: 0.5 ether}(1);

        // 验证质押金额是否已增加
        (address stakeUser, uint256 amount, uint256 newTimestamp, bool isSlash) = dcAllocator.stakes(1);
        assertEq(stakeUser, user1);
        assertEq(amount, 1.5 ether);
        assertFalse(isSlash);

        // 验证时间戳是否已更新
        assertTrue(newTimestamp > initialTimestamp);
        assertEq(newTimestamp, block.timestamp);
    }

    function test_RevertWhen_StakeMore_NotStaker() public {
        // 用户1初始质押
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        dcAllocator.stake{value: 1 ether}(1);

        // 用户2尝试增加质押金额，应该失败
        vm.deal(user2, 0.5 ether);
        vm.prank(user2);
        vm.expectRevert("Not the staker");
        dcAllocator.stakeMore{value: 0.5 ether}(1);
    }

    function test_RevertWhen_StakeMore_SlashedStake() public {
        // 用户1初始质押
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        dcAllocator.stake{value: 1 ether}(1);

        // 由committeeMultisig地址执行slash
        address multisig = address(0x7);
        vm.prank(multisig);
        dcAllocator.slash(1, "test reason");

        // 用户1尝试增加已被slash的质押金额，应该失败
        vm.deal(user1, 0.5 ether);
        vm.prank(user1);
        vm.expectRevert("Stake has been slashed");
        dcAllocator.stakeMore{value: 0.5 ether}(1);
    }

    function test_RevertWhen_StakeMore_ZeroAmount() public {
        // 用户1初始质押
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        dcAllocator.stake{value: 1 ether}(1);

        // 用户1尝试增加0金额，应该失败
        vm.prank(user1);
        vm.expectRevert("Amount must be >= 0.0001 ETH");
        dcAllocator.stakeMore{value: 0}(1);
    }

    // 分页查询测试
    function test_GetAllStakesPaged() public {
        // 用户1质押 issue 1
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        dcAllocator.stake{value: 1 ether}(1);

        // 用户2质押 issue 2
        vm.deal(user2, 2 ether);
        vm.prank(user2);
        dcAllocator.stake{value: 2 ether}(2);

        // 用户1取回 issue 1
        vm.warp(block.timestamp + 181 days);
        vm.prank(user1);
        dcAllocator.unstake(1);

        // 分页获取
        DCAllocator.Stake[] memory page1 = dcAllocator.getAllStakesPaged(0, 1);
        assertEq(page1.length, 1);
        assertEq(page1[0].user, address(0)); // 已取回

        DCAllocator.Stake[] memory page2 = dcAllocator.getAllStakesPaged(1, 1);
        assertEq(page2.length, 1);
        assertEq(page2[0].user, user2);

        // 超出范围
        DCAllocator.Stake[] memory emptyPage = dcAllocator.getAllStakesPaged(10, 5);
        assertEq(emptyPage.length, 0);
    }
}
