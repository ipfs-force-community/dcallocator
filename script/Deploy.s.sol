// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DCAllocator} from "../src/DCAllocator.sol";

contract DeployScript is Script {
    DCAllocator public dcAllocator;

    // 从环境变量中读取配置
    function getConfig() internal view returns (
        uint256 threshold,
        address vault,
        uint256 challengePeriod
    ) {
        // 从环境变量获取阈值
        threshold = vm.envOr("THRESHOLD", uint256(2));
        require(threshold > 0, "Invalid threshold");
        // 从环境变量获取保险库地址
        string memory vaultStr = vm.envOr("VAULT", string(""));
        if (bytes(vaultStr).length > 0) {
            vault = parseAddr(vaultStr);
        } else {
            vault = address(0);
        }
        // 从环境变量获取挑战期（天数）
        uint256 challengePeriodDays = vm.envOr("CHALLENGE_PERIOD", uint256(180));
        challengePeriod = challengePeriodDays;
    }

    function run() public {
        (
            uint256 threshold,
            address vault,
            uint256 challengePeriod
        ) = getConfig();
        
        console.log("Deploying DCAllocator with the following configuration:");
        console.log("Threshold:", threshold);
        console.log("Vault:", vault);
        console.log("Challenge Period (days):", challengePeriod);
        
        vm.startBroadcast();
        
        dcAllocator = new DCAllocator(
            threshold,
            vault,
            challengePeriod
        );
        
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
