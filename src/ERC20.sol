// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StakingToken is ERC20 {
    
    address immutable i_owner;


    constructor() ERC20("Token","TK"){
        i_owner = msg.sender;
    }

    function mint(address to, uint256 amount) external { //mint for testing purposes
        require(msg.sender == owner);
        _mint(to, amount);
    }

}