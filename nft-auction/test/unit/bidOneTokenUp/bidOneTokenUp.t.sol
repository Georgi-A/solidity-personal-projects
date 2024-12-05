// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Base_Test} from "test/Base.t.sol";
import {Errors} from "src/utils/Errors.sol";
import {NFTAuction} from "src/NFTAuction.sol";

contract BidOneTokenUp_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        vm.startPrank(sellerOne);
        createAuction(tokenOne, durationDays);
        vm.stopPrank();
        vm.startPrank(bidderOne);
    }

    function test_RevertGiven_AuctionDoesNotExist(uint256 auctionId) external {
        vm.assume(auctionId > 1);
        
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.AuctionDoesNotExist.selector
            )
        });
        nftAuction.bidOneTokenUp(auctionId);
    }

    function test_RevertWhen_AuctionHasFinished(uint256 duration) external {
        uint256 deadline = block.timestamp + 4 days;
        vm.assume(duration > deadline);
        vm.warp(duration);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.AuctionFinished.selector,
                deadline
            )
        });
        nftAuction.bidOneTokenUp(1);
    }

    function test_RevertWhen_UserHasInsufficientFunds() external {
        nftAuction.createBid(1, toDecimals(200));

        vm.startPrank(bidderTwo);
        nftAuction.createBid(1, toDecimals(1200));
        vm.stopPrank();

        // it should revert
        vm.startPrank(bidderOne);
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InsufficientFunds.selector,
                daiContract.balanceOf(bidderOne)
            )
        });
        nftAuction.bidOneTokenUp(1);
    }

    function test_WhenBidderIsAbleToOutbid() external {
        nftAuction.createBid(1, toDecimals(250));

        vm.startPrank(bidderTwo);
        nftAuction.createBid(1, toDecimals(700));
        vm.stopPrank();

        // it should outbid by 1 token
        vm.startPrank(bidderOne);
        vm.expectEmit();
        uint256 expectedDeposit = toDecimals(700 - 250 + 1);
        emit NFTAuction.LogBidOneTokenUp(address(bidderOne), 1, expectedDeposit);
        nftAuction.bidOneTokenUp(1);

        uint256 expectedBidderBalance = amountToDeposit - toDecimals(701);
        uint256 expectedContractBalance = toDecimals(700 + 701);
        assertEq(daiContract.balanceOf(bidderOne), expectedBidderBalance);
        assertEq(daiContract.balanceOf(address(nftAuction)), expectedContractBalance);
    }
}
