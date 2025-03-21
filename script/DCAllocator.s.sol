// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DCAllocator} from "../src/DCAllocator.sol";

contract DCAllocatorScript is Script {
    DCAllocator public dcAllocator;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // 创建初始委员会成员列表
        address[] memory initialCommittee = new address[](3);
        initialCommittee[0] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // 示例地址，请替换为实际地址
        initialCommittee[1] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // 示例地址，请替换为实际地址
        initialCommittee[2] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906; // 示例地址，请替换为实际地址

        // 设置阈值和最大委员会人数
        uint256 threshold = 2;
        uint256 maxCommitteeSize = 5;
        
        // 设置保险库地址和挑战期
        address vault = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65; // 示例地址，请替换为实际地址
        uint256 challengePeriod = 180; // 180天

        // 部署合约
        dcAllocator = new DCAllocator(initialCommittee, threshold, maxCommitteeSize, vault, challengePeriod);

        vm.stopBroadcast();
    }
}
