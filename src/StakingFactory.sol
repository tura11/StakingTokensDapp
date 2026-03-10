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
    error StakingFactory__MinTimeNotMet();
    error StakingFactory__UserNotStaked();
    error StakingFactory__TimeLockNotExpired();





    event Deposit(address indexed tokenAddress, address indexed staker, uint256 amount);
    event Stake(address indexed tokenAddress, address indexed staker, uint256 amount);
    event Unstake(address indexed tokenAddress, address indexed staker, uint256 stakedAmount, uint256 reward);
    event Withdraw(address indexed tokenAddress, address indexed staker, uint256 amount);


    struct APYchange{
        uint256 newApy;
        uint256 effectiveAt;
    }


    // User Balance
    mapping(address => mapping(address => uint256)) public s_balances;
    // Stake amount
    mapping(address => mapping(address => uint256)) public s_stakes;
    // APY in basis points (10000 = 100%)
    mapping(address => uint256) public s_apy;
    // Stake started time
    mapping(address => mapping(address => uint256)) public s_stakeStartTime;

    mapping(address => APYchange) public s_apychanges;

    uint256 public constant MAX_DEPOSIT = 100 ether;
    uint256 public constant MAX_WITHDRAW = 100 ether;
    uint256 public constant MIN_STAKE_TIME = 7 days;
    uint256 public constant APY_TIME_LOCK = 7 days;

    constructor() Ownable(msg.sender){}

    // ============ DEPOSIT ============
    function depositTokenToContract(address tokenAddress, uint256 amount) external {
        if(tokenAddress == address(0)) {
            revert StakingFactory__ZeroAddress();
        }
        if(amount == 0 || amount > MAX_DEPOSIT) {
            revert StakingFactory__InvalidAmount();
        }

        s_balances[tokenAddress][msg.sender] += amount;
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(tokenAddress, msg.sender, amount);
    }

    // ============ STAKE ============
    function tokenStake(address tokenAddress, uint256 amount) external {
        if(tokenAddress == address(0)) {
            revert StakingFactory__ZeroAddress();
        }
        if(amount == 0 || amount > s_balances[tokenAddress][msg.sender]) {
            revert StakingFactory__InvalidAmount();
        }

 
        s_balances[tokenAddress][msg.sender] -= amount;
        s_stakes[tokenAddress][msg.sender] += amount;
        
        // if its user first stake set start time
        if(s_stakeStartTime[tokenAddress][msg.sender] == 0) {
            s_stakeStartTime[tokenAddress][msg.sender] = block.timestamp;
        }
        
        emit Stake(tokenAddress, msg.sender, amount);
    }

    // ============ UNSTAKE + CLAIM REWARDS ============
    function unstakeAndClaimRewards(address tokenAddress, uint256 amount) external {
        if(tokenAddress == address(0)) {
            revert StakingFactory__ZeroAddress();
        }
        if(amount == 0 || amount > MAX_WITHDRAW) {
            revert StakingFactory__InvalidAmount();
        }

        uint256 stakedAmount = s_stakes[tokenAddress][msg.sender];
        if(stakedAmount < amount) {
            revert StakingFactory__InvalidAmount();
        }

        uint256 stakeTime = s_stakeStartTime[tokenAddress][msg.sender];
        if(block.timestamp < stakeTime + MIN_STAKE_TIME) {
            revert StakingFactory__MinTimeNotMet();
        }

        uint256 reward = calculateReward(tokenAddress, msg.sender);

        s_stakes[tokenAddress][msg.sender] -= amount;

        // Reset stake time if user unstakes all
        if(s_stakes[tokenAddress][msg.sender] == 0) {
            s_stakeStartTime[tokenAddress][msg.sender] = 0;
        }

        // Sending amount + reward
        IERC20(tokenAddress).safeTransfer(msg.sender, amount + reward);

        emit Unstake(tokenAddress, msg.sender, amount, reward);
    }

    // ============ WITHDRAW BALANCE ============
    function withdrawBalance(address tokenAddress, uint256 amount) external {
        if(tokenAddress == address(0)) {
            revert StakingFactory__ZeroAddress();
        }
        if(amount == 0 || amount > MAX_WITHDRAW) {
            revert StakingFactory__InvalidAmount();
        }

        uint256 balance = s_balances[tokenAddress][msg.sender];
        if(balance < amount) {
            revert StakingFactory__InvalidAmount();
        }

        s_balances[tokenAddress][msg.sender] -= amount;
        IERC20(tokenAddress).safeTransfer(msg.sender, amount);

        emit Withdraw(tokenAddress, msg.sender, amount);
    }


    function proposeNewAPY(address tokenAddress, uint256 apyBasisPoints) external onlyOwner {
        if(tokenAddress == address(0)) {
            revert StakingFactory__ZeroAddress();
        }
        if(apyBasisPoints == 0) {
            revert StakingFactory__ApyCannotBeZero();
        }
        s_apychanges[tokenAddress] = APYchange({
            newApy: apyBasisPoints,
            effectiveAt: block.timestamp + APY_TIME_LOCK
        });
    }


    function executeNewAPY(address tokenAddress) external onlyOwner {
        if(tokenAddress == address(0)) {
            revert StakingFactory__ZeroAddress();
        }
        APYchange memory change = s_apychanges[tokenAddress];
        if(block.timestamp < change.effectiveAt) {
            revert StakingFactory__TimeLockNotExpired();
        }
        s_apy[tokenAddress] = change.newApy;
        delete s_apychanges[tokenAddress];
    }


    // ============ VIEW FUNCTIONS ============
    
    /**
     * Calculates reward for user
     * Formula: (staked * apy * time_elapsed) / (365 days * 10000)
     */
    function calculateReward(address tokenAddress, address user) public view returns (uint256) {
        uint256 apy = s_apy[tokenAddress];
        if(apy == 0) {
            revert StakingFactory__ApyCannotBeZero();
        }

        uint256 stakedAmount = s_stakes[tokenAddress][user];
        if(stakedAmount == 0) {
            revert StakingFactory__InvalidAmount();
        }

        uint256 startTime = s_stakeStartTime[tokenAddress][user];
        if(startTime == 0) {
            revert StakingFactory__UserNotStaked();
        }

        uint256 timeElapsed = block.timestamp - startTime;
        
        // reward = (staked * apy * time) / (365 days * 10000)
        uint256 reward = (stakedAmount * apy * timeElapsed) / (365 days * 10000);
        return reward;
    }

    /**
     * Return user info
     */
    function getUserInfo(address tokenAddress, address user) external view returns (
        uint256 balance,
        uint256 staked,
        uint256 pendingReward,
        uint256 apy
    ) {
        return (
            s_balances[tokenAddress][user],
            s_stakes[tokenAddress][user],
            calculateReward(tokenAddress, user),
            s_apy[tokenAddress]
        );
    }

    /**
     * Returns time until user can unstake
     */
    function timeUntilCanUnstake(address tokenAddress, address user) external view returns (uint256) {
        uint256 startTime = s_stakeStartTime[tokenAddress][user];
        if(startTime == 0) return 0;
        
        uint256 unlockTime = startTime + MIN_STAKE_TIME;
        if(block.timestamp >= unlockTime) {
            return 0;
        }
        return unlockTime - block.timestamp;
    }
}
