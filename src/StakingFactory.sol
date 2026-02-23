// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingFactory {
    using SafeERC20 for IERC20;
    error StakingFactory__ZeroAddress();
    error StakingFactory__InvalidAmount(); 
    
    address private s_owner;


    mapping(address=>mapping(address=>uint256)) public s_balancesForExactToken;
    mapping(address=>uint256) public s_stakes;

    uint256 public constant MAX_DEPOSIT = 10 ether;
    uint256 public constant MAX_WITHDRAW = 20 ether;


    constructor() {
        s_owner = msg.sender; 
    }


    function depositTokenToContract(address tokenAddress, uint256 amount) external {
        if(tokenAddress == address(0)) {
            revert StakingFactory__ZeroAddress();
        }
        if(amount == 0 || amount > MAX_DEPOSIT) {
            revert StakingFactory__InvalidAmount();
        }
        
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        s_balancesForExactToken[tokenAddress][msg.sender] += amount;
        
    }




}