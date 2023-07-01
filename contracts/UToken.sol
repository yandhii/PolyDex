//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./ERC20.sol";

contract UToken is ERC20 {

    constructor() ERC20("UToken", "UTK") {
        // Mint 50 UToken tokens to the contract deployer
        _mint(msg.sender, 50 * 10**18);
    }
}