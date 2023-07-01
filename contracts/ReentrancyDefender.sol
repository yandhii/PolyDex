// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

abstract contract ReentrancyDefender{
    bool lock = false;

    modifier nonReentrant(){
        require(lock == false, "ReentrancyDefender: No Reentrancy");
        lock = true;
        _;
        lock = false;
    }
}