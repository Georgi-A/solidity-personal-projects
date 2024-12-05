// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {NFTAuction} from "src/NFTAuction.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract Base_Test is Test {
    NFTAuction nftAuction;

    //// CONSTANTS ////
    uint256 reservePrice = 200 * 10 ** 18;
    uint256 durationDays = 4;
    uint256 tokenOne = 1;
    uint256 amountToDeposit = 1000 * 10 ** 18;

    //// TOKENS ////
    MockERC20 wethContract;
    MockERC20 daiContract;
    IERC20[] supportedTokens;
    MockERC721 nftContract;

    //// USERS ////
    address public owner = makeAddr("owner");
    address public bidderOne = makeAddr("bidderOne");
    address public bidderTwo = makeAddr("bidderTwo");
    address public sellerOne = makeAddr("sellerOne");
    address public sellerTwo = makeAddr("sellerTwo");

    function setUp() public virtual {
        //// SET TOKENS ////
        daiContract = new MockERC20("Dai", "DAI");
        wethContract = new MockERC20("Wrapped ETH", "WETH");
        nftContract = new MockERC721("NFT", "NFT");

        //// DEPLOY ////
        vm.startPrank(owner);
        supportedTokens.push(daiContract);
        supportedTokens.push(wethContract);
        nftAuction = new NFTAuction(supportedTokens);
        vm.stopPrank();

        //// SET BIDDERS WITH FUNDS AND APPROVE////
        vm.startPrank(bidderOne);
        daiContract.mint(bidderOne, amountToDeposit);
        daiContract.approve(address(nftAuction), amountToDeposit);
        vm.stopPrank();

        vm.startPrank(bidderTwo);
        daiContract.mint(bidderTwo, amountToDeposit * 2);
        daiContract.approve(address(nftAuction), amountToDeposit * 2);
        vm.stopPrank();

        //// SET SELLER WITH NFT ////
        vm.startPrank(sellerOne);
        nftContract.mint(sellerOne, tokenOne);
        nftContract.mint(sellerOne, 2);
        vm.stopPrank();
    }

    //// HELPERS ////
    function createAuction(uint256 tokenId, uint256 duration) internal {
        nftAuction.createAuction(address(nftContract), tokenId, duration, address(daiContract), reservePrice);  
    }

    function wonFinishedAuction() internal {
        createAuction(tokenOne, durationDays);
        vm.stopPrank();
        vm.startPrank(bidderOne);
        nftAuction.createBid(1, amountToDeposit);
        vm.stopPrank();
        vm.warp(block.timestamp + (durationDays * 1 days) + 1 minutes);
    }

    function toDecimals(uint256 amount) internal pure returns (uint256) {
        return amount * 10 ** 18;
    }
}
