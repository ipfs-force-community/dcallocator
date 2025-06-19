// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DCAllocator} from "../src/DCAllocator.sol";

contract DCAllocatorScript is Script {
    DCAllocator public dcAllocator;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // 设置阈值和最大委员会人数
        uint256 threshold = 2;
        
        // 设置保险库地址和挑战期
        address vault = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
        uint256 challengePeriod = 180; // 180天

        // 部署合约
        dcAllocator = new DCAllocator(threshold, vault, challengePeriod);

        vm.stopBroadcast();
    }
}
