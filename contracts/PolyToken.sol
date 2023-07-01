//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./ERC20.sol";

contract PolyToken is ERC20 {

    constructor() ERC20("PolyToken", "PTK") {
        // Mint 50 PolyToken tokens to the contract deployer
        _mint(msg.sender, 50 * 10**18);
    }
}


