// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ReentrancyGuard
 * @dev 防止重入攻击的基类
 */
contract ReentrancyGuard {
    // 重入锁状态变量
    bool private locked;

    // 重入锁修饰符
    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }
} 