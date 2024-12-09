// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Base_Test } from "test/Base.t.sol";
import { Errors } from "src/utils/Errors.sol";
import { NFTAuction } from "src/NFTAuction.sol";

contract bidderWithdraw_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        vm.prank(sellerOne);
        createAuction(1, durationDays);
        vm.prank(bidderOne);
    }
    function test_RevertGiven_AuctionDoesNotExist() external {
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.AuctionDoesNotExist.selector
            )
        });
        nftAuction.bidderWithdraw(2);
    }

    modifier givenAuctionDoesExist() {
        _;
    }

    function test_RevertWhen_BidderIsNotPartOfAuction() external givenAuctionDoesExist {
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.NotPartOfAuction.selector
            )
        });
        nftAuction.bidderWithdraw(1);
    }

    function test_RevertWhen_BidderHasWonTheAuction() external givenAuctionDoesExist {
        nftAuction.createBid(1, amountToDeposit);
        vm.warp(block.timestamp + (durationDays * 1 days) + 1 minutes);

        vm.prank(bidderOne);
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.YouAreTheWinner.selector,
                1
            )
        });
        nftAuction.bidderWithdraw(1);
    }

    function test_WhenBidderHasNotWonAuction() external givenAuctionDoesExist {
        nftAuction.createBid(1, toDecimals(250));
        vm.prank(bidderTwo);
        nftAuction.createBid(1, amountToDeposit);

        vm.warp(block.timestamp + (durationDays * 1 days) + 1 minutes);

        vm.prank(bidderOne);
        // it should allow withdraw
        vm.expectEmit();
        emit NFTAuction.LogBidderWithdraw(bidderOne, toDecimals(250));
        nftAuction.bidderWithdraw(1);
    }
}
