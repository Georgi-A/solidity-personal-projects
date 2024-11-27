// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { NFTAuction } from "src/NFTAuction.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { MockERC721 } from "test/mocks/MockERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract Base_Test is Test {
    NFTAuction nftAuction;

    //// TOKENS ////
    MockERC20 wEth;
    MockERC20 dai;
    IERC20[] supportedTokens;
    MockERC721 nft;

    //// USERS ////
    address owner = makeAddr("owner");
    address bidderOne = makeAddr("bidderOne");
    address bidderTwo = makeAddr("bidderTwo");
    address sellerOne = makeAddr("sellerOne");
    address sellerTwo = makeAddr("sellerTwo");

    function setUp() public virtual {
        //// SET TOKENS ////
        dai = new MockERC20("Dai", "DAI");
        wEth = new MockERC20("Wrapped ETH", "WETH");
        nft = new MockERC721("NFT", "NFT");

        //// DEPLOY ////
        vm.startPrank(owner);
        supportedTokens.push(dai);
        supportedTokens.push(wEth);
        nftAuction = new NFTAuction(supportedTokens);
        vm.stopPrank();

        //// SET BIDDERS WITH FUNDS ////
        vm.startPrank(bidderOne);
        dai.mint(bidderOne, 1000);
        IERC20(dai).approve(address(nftAuction), address(bidderOne).balance);
        vm.stopPrank();

        vm.startPrank(bidderTwo);
        wEth.mint(bidderTwo, 100);
        IERC20(wEth).approve(address(nftAuction), address(bidderTwo).balance);
        vm.stopPrank();

        //// SET SELLERS WITH NFTs ////
        vm.startPrank(sellerOne);
        nft.mint(sellerOne, 1);
        nft.mint(sellerOne, 2);
        vm.stopPrank();

        vm.startPrank(sellerTwo);
        nft.mint(sellerTwo, 3);
        vm.stopPrank();
    }
}