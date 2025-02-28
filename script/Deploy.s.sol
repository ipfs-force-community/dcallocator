// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {DCAllocator} from "../src/DCAllocator.sol";

contract DeployScript is Script {
    DCAllocator public dcAllocator;

    // 从环境变量中读取配置
    function getConfig() internal returns (
        address[] memory committee,
        uint256 threshold,
        uint256 maxCommitteeSize,
        address vault,
        uint256 challengePeriod
    ) {
        // 从环境变量中读取委员会成员地址
        string memory committeeStr = vm.envOr("COMMITTEE", string(""));
        string[] memory committeeAddrs = splitString(committeeStr, ",");
        
        committee = new address[](committeeAddrs.length);
        for (uint i = 0; i < committeeAddrs.length; i++) {
            committee[i] = parseAddr(committeeAddrs[i]);
        }
        
        // 从环境变量中读取其他配置
        threshold = vm.envOr("THRESHOLD", uint256(2));
        maxCommitteeSize = vm.envOr("MAX_COMMITTEE_SIZE", uint256(5));
        vault = vm.envOr("VAULT", address(0));
        uint256 challengePeriodDays = vm.envOr("CHALLENGE_PERIOD", uint256(180));
        challengePeriod = challengePeriodDays * 1 days;
        
        // 打印配置信息
        console.log("Deploying DCAllocator with the following configuration:");
        console.log("Committee members:");
        for (uint i = 0; i < committee.length; i++) {
            console.log(committee[i]);
        }
        console.log("Threshold:", threshold);
        console.log("Max Committee Size:", maxCommitteeSize);
        console.log("Vault:", vault);
        console.log("Challenge Period (days):", challengePeriod / 1 days);
    }

    function run() public {
        // 获取配置
        (
            address[] memory committee,
            uint256 threshold,
            uint256 maxCommitteeSize,
            address vault,
            uint256 challengePeriod
        ) = getConfig();
        
        // 验证配置
        require(committee.length > 0, "Committee cannot be empty");
        require(threshold > 0 && threshold <= committee.length, "Invalid threshold");
        require(maxCommitteeSize >= committee.length, "Max committee size must be >= committee length");
        
        vm.startBroadcast();

        // 部署合约
        dcAllocator = new DCAllocator(committee, threshold, maxCommitteeSize);
        
        // 设置保险库地址（如果提供）
        if (vault != address(0)) {
            dcAllocator.setVault(vault);
        }
        
        // 设置挑战期（如果与默认值不同）
        if (challengePeriod != 180 days) {
            dcAllocator.setChallengePeriod(challengePeriod);
        }

        console.log("DCAllocator deployed at:", address(dcAllocator));

        vm.stopBroadcast();
    }
    
    // 辅助函数：将字符串按分隔符分割
    function splitString(string memory str, string memory delimiter) internal pure returns (string[] memory) {
        bytes memory strBytes = bytes(str);
        bytes memory delimiterBytes = bytes(delimiter);
        
        if (strBytes.length == 0) {
            string[] memory empty = new string[](0);
            return empty;
        }
        
        uint count = 1;
        for (uint i = 0; i < strBytes.length; i++) {
            bool isDelimiter = true;
            for (uint j = 0; j < delimiterBytes.length; j++) {
                if (i + j >= strBytes.length || strBytes[i + j] != delimiterBytes[j]) {
                    isDelimiter = false;
                    break;
                }
            }
            if (isDelimiter) {
                count++;
                i += delimiterBytes.length - 1;
            }
        }
        
        string[] memory parts = new string[](count);
        uint partIndex = 0;
        uint startIndex = 0;
        
        for (uint i = 0; i <= strBytes.length; i++) {
            if (i == strBytes.length || (i <= strBytes.length - delimiterBytes.length && isSubstringAt(strBytes, delimiterBytes, i))) {
                uint length = i - startIndex;
                bytes memory part = new bytes(length);
                for (uint j = 0; j < length; j++) {
                    part[j] = strBytes[startIndex + j];
                }
                parts[partIndex] = string(part);
                partIndex++;
                
                if (i < strBytes.length) {
                    i += delimiterBytes.length - 1;
                    startIndex = i + 1;
                }
            }
        }
        
        return parts;
    }
    
    // 辅助函数：检查子字符串是否在指定位置
    function isSubstringAt(bytes memory str, bytes memory substr, uint pos) internal pure returns (bool) {
        if (pos + substr.length > str.length) {
            return false;
        }
        
        for (uint i = 0; i < substr.length; i++) {
            if (str[pos + i] != substr[i]) {
                return false;
            }
        }
        
        return true;
    }
    
    // 辅助函数：将字符串解析为地址
    function parseAddr(string memory s) internal pure returns (address) {
        bytes memory ss = bytes(s);
        require(ss.length == 42, "Invalid address length");
        require(ss[0] == '0' && ss[1] == 'x', "Invalid address format");
        
        uint160 addr = 0;
        for (uint i = 2; i < 42; i++) {
            addr *= 16;
            uint8 digit = uint8(ss[i]);
            if (digit >= 48 && digit <= 57) {
                // 0-9
                addr += digit - 48;
            } else if (digit >= 65 && digit <= 70) {
                // A-F
                addr += digit - 55;
            } else if (digit >= 97 && digit <= 102) {
                // a-f
                addr += digit - 87;
            } else {
                revert("Invalid address character");
            }
        }
        
        return address(addr);
    }
}
