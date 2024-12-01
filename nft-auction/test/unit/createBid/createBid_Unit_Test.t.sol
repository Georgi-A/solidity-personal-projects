// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Base_Test} from "test/Base.t.sol";
import {Errors} from "src/utils/Errors.sol";
import {Constants} from "src/utils/Constants.sol";
import {NFTAuction} from "src/NFTAuction.sol";

import { console } from "forge-std/console.sol";

contract CreateBid_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        createAuction(tokenOne, durationDays);

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
        nftAuction.createBid(auctionId, 100);
    }

    function test_RevertGiven_AuctionHasFinished(uint256 duration) external {
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
        nftAuction.createBid(1, 100);
    }

    function test_RevertGiven_ZeroAmount() external {
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.ZeroInput.selector
            )
        });
        nftAuction.createBid(1, 0);
    }

    function test_RevertGiven_AmountLessThanHigherBid(uint256 amount) external {
        nftAuction.createBid(1, 500);

        vm.startPrank(bidderTwo);
        
        amount = bound({ x: amount, min: 1, max: 499});
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.PriceNotMet.selector,
                500, amount
            )
        });
        // it should revert
        nftAuction.createBid(1, amount);
    }

    function test_RevertGiven_UserHasInsufficientFunds() external {
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InsufficientFunds.selector,
                amountToDeposit
            )
        });
        nftAuction.createBid(1, amountToDeposit * 2);
    }

    function test_GivenAllParametersAreValid() external {
        vm.expectEmit();
        emit NFTAuction.LogCreateBid(address(bidderOne), 1, 250);
        
        // it should created a bid
        nftAuction.createBid(1, 250);

        NFTAuction.Auction memory auction = nftAuction.getAuction(1);
        assertEq(auction.highestBid, 250);
        assertEq(auction.highestBidder, bidderOne);
    }
}
