// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// Auction dependencies
import {Base_Test} from "test/Base.t.sol";
import {Errors} from "src/utils/Errors.sol";
import {NFTAuction} from "src/NFTAuction.sol";

contract blackListSeller_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        vm.prank(sellerOne);
        wonFinishedAuction();
    }

    function test_RevertGiven_AuctionDoesNotExist() external {
        vm.prank(bidderOne);

        // it should revert
        vm.expectRevert({revertData: abi.encodeWithSelector(Errors.AuctionDoesNotExist.selector)});
        nftAuction.blackListSeller(2);
    }

    modifier givenAuctionDoesExist() {
        _;
    }

    function test_RevertWhen_BidderHasNotWonTheAuction() external givenAuctionDoesExist {
        vm.prank(bidderTwo);

        // it should revert
        vm.expectRevert({revertData: abi.encodeWithSelector(Errors.CantBlackList.selector)});
        nftAuction.blackListSeller(1);
    }

    function test_RevertWhen_BidderHasWonAndReceivedNFT() external givenAuctionDoesExist {
        vm.warp(block.timestamp + 1 days);
        vm.prank(sellerOne);
        nftContract.safeTransfer(bidderOne, tokenOne);
        vm.prank(bidderOne);

        // it should revert
        vm.expectRevert({revertData: abi.encodeWithSelector(Errors.YouAreTheOwner.selector)});
        nftAuction.blackListSeller(1);
    }

    function test_WhenEnoughTimeHasPassed() external givenAuctionDoesExist {
        vm.warp(block.timestamp + 1 days);
        vm.prank(bidderOne);

        // it should blacklist seller
        vm.expectEmit();
        emit NFTAuction.LogBlackListSeller(bidderOne, sellerOne, amountToDeposit);
        nftAuction.blackListSeller(1);
    }

    function test_WhenSellerDoesNotOwnTheListedNFT() external givenAuctionDoesExist {
        vm.prank(sellerOne);
        nftContract.safeTransfer(bidderTwo, tokenOne);
        vm.prank(bidderOne);

        // it should blacklist seller
        vm.expectEmit();
        emit NFTAuction.LogBlackListSeller(bidderOne, sellerOne, amountToDeposit);
        nftAuction.blackListSeller(1);
    }
}
