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
    uint256 reservePrice = 2000;
    uint256 durationDays = 4;
    uint256 tokenOne = 1;

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

        //// SET BIDDERS WITH FUNDS ////
        vm.startPrank(bidderOne);
        daiContract.mint(bidderOne, 1000);
        IERC20(daiContract).approve(address(nftAuction), address(bidderOne).balance);
        vm.stopPrank();

        vm.startPrank(bidderTwo);
        wethContract.mint(bidderTwo, 100);
        IERC20(wethContract).approve(address(nftAuction), address(bidderTwo).balance);
        vm.stopPrank();

        //// SET SELLERS WITH NFTs ////
        vm.startPrank(sellerOne);
        nftContract.mint(sellerOne, 1);
        nftContract.mint(sellerOne, 2);
        vm.stopPrank();

        vm.startPrank(sellerTwo);
        nftContract.mint(sellerTwo, 3);
        vm.stopPrank();
    }

    function createAuction() external {
        vm.startPrank(sellerOne);
        nftAuction.createAuction(address(nftContract), tokenOne, durationDays, address(daiContract), reservePrice);
        vm.stopPrank();
    }
}
