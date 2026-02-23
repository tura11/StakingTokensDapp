// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract StakingFactory is Ownable {
    using SafeERC20 for IERC20;
    error StakingFactory__ZeroAddress();
    error StakingFactory__InvalidAmount(); 
    error StakingFactory__ApyCannotBeZero();


    event Deposit(address tokenAddress, address staker, uint256 amount);
    event Withdraw(address tokenAddress, address staker, uint256 amount);


    address private s_owner;


    mapping(address=>mapping(address=>uint256)) public s_balancesForExactToken;
    mapping(address=>mapping(address=>uint256)) public s_stakes;
    mapping(address=>uint256) public s_apy; // APY in basis points, 1000 = 10% etc.
    mapping(address=>mapping(address=>uint256)) public s_stakeStartTime;

    uint256 public constant MAX_DEPOSIT = 10 ether;
    uint256 public constant MAX_WITHDRAW = 20 ether;
    uint256 public constant MIN_TIME_STAKE = 7 days;


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


        s_balancesForExactToken[tokenAddress][msg.sender] += amount;
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(tokenAddress, msg.sender, amount);

    }


    function tokenStake(address tokenAddress, uint256 amount) external {
        if(tokenAddress == address(0)) {
            revert StakingFactory__ZeroAddress();
        }
        uint256 userBalance = s_balancesForExactToken[tokenAddress][msg.sender];
        if(amount == 0 || amount > userBalance) {
            revert StakingFactory__InvalidAmount();
        }
        s_balancesForExactToken[tokenAddress][msg.sender] -= amount;
        s_stakes[tokenAddress][msg.sender] += amount;
        if(s_stakeStartTime[tokenAddress][msg.sender] == 0) {
            s_stakeStartTime[tokenAddress][msg.sender] = block.timestamp;
        }
    }


    function withdrawTokenStakesFromContract(address tokenAddress, uint256 amount) external {
        if(tokenAddress == address(0)) {
            revert StakingFactory__ZeroAddress();
        }
        if(amount == 0 || amount > MAX_WITHDRAW) {
            revert StakingFactory__InvalidAmount();
        }

        uint256 stakesBalance = s_stakes[tokenAddress][msg.sender];
        if(stakesBalance < amount) {
            revert StakingFactory__InvalidAmount();
        }
        s_stakes[tokenAddress][msg.sender] -= amount;
        IERC20(tokenAddress).safeTransfer(msg.sender, amount);

        emit Withdraw(tokenAddress, msg.sender, amount);
    }


    function withdrawTokenBalanceFromContract(address tokenAddress, uint256 amount) external {
        if(tokenAddress == address(0)) {
            revert StakingFactory__ZeroAddress();
        }
        if(amount == 0 || amount > MAX_WITHDRAW) {
            revert StakingFactory__InvalidAmount();
        }
        uint256 balance = s_balancesForExactToken[tokenAddress][msg.sender];
        if(balance < amount) {
            revert StakingFactory__InvalidAmount();
        }
        s_balancesForExactToken[tokenAddress][msg.sender] -= amount;
        IERC20(tokenAddress).safeTransfer(msg.sender, amount);
    }



    function setTokenAPY(address tokenAddress, uint256 apyBasisPoints) internal onlyOwner {
        if(tokenAddress == address(0)) {
            revert StakingFactory__ZeroAddress();
        }

        if(apyPercentage == 0) {
            revert StakingFactory__ApyCannotBeZero();
        }
        s_apy[tokenAddress] = apyBasisPoints;
    }


    function calculateReward(address tokenAddress) external view returns (uint256) {
        if(tokenAddress == address(0)) {
            revert StakingFactory__ZeroAddress();
        }
        uint256 apy = s_apy[tokenAddress];
        if(apy == 0) {
            revert StakingFactory__ApyCannotBeZero();
        }
        uint256 amount = s_balancesForExactToken[tokenAddress][msg.sender];
        uint256 startTime = s_stakeStartTime[tokenAddress][msg.sender];
        uint256 timeElapsed = block.timestamp - startTime;
        if(timeElapsed == 0) {
            return 0;
        }
        uint256 reward = (amount * apy * timeElapsed) / (365 days * 10000);
        return reward;
    }

}


//REWARDS = (Amount × APY × TimeElapsed) / (365 days × 10000)