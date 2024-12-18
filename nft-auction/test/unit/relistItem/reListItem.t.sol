// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// Auction dependencies
import {Base_Test} from "test/Base.t.sol";
import {Errors} from "src/utils/Errors.sol";
import {NFTAuction} from "src/NFTAuction.sol";
import {Constants} from "src/utils/Constants.sol";

contract reListItem_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        vm.prank(sellerOne);
    }

    function test_RevertGiven_AuctionDoesNotExist() external {
        // it should revert
        vm.expectRevert({revertData: abi.encodeWithSelector(Errors.AuctionDoesNotExist.selector)});
        nftAuction.reListItem(2, durationDays, reservePrice);
    }

    modifier givenAuctionDoesExist() {
        _;
    }

    function test_RevertGiven_DurationIsLessThanAllowedDuration(uint256 duration) external givenAuctionDoesExist {
        createAuction(1, durationDays);
        vm.warp(block.timestamp + (durationDays * 1 days) + 1 minutes);
        vm.assume(duration < Constants.MIN_DURATION);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.AuctionDurationOutOfBounds.selector, Constants.MIN_DURATION, Constants.MAX_DURATION
            )
        });
        nftAuction.reListItem(1, duration, reservePrice);
    }

    function test_RevertGiven_DurationIsHigherThanAllowedDuration(uint256 duration) external givenAuctionDoesExist {
        createAuction(1, durationDays);
        vm.warp(block.timestamp + (durationDays * 1 days) + 1 minutes);
        vm.assume(duration > Constants.MAX_DURATION && duration < 1000);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.AuctionDurationOutOfBounds.selector, Constants.MIN_DURATION, Constants.MAX_DURATION
            )
        });
        nftAuction.reListItem(1, duration, reservePrice);
    }

    modifier givenDurationIsWithinAllowedDuration() {
        _;
    }

    function test_RevertWhen_UserIsNotOwnerOfAuction(address user)
        external
        givenAuctionDoesExist
        givenDurationIsWithinAllowedDuration
    {
        createAuction(1, durationDays);
        vm.warp(block.timestamp + durationDays);

        vm.assume(user != sellerOne);
        // it should revert
        vm.prank(user);
        vm.expectRevert({revertData: abi.encodeWithSelector(Errors.NotOwnerOfAuction.selector)});
        nftAuction.reListItem(1, durationDays, reservePrice);
    }

    function test_RevertWhen_AuctionHasBeenWon() external givenAuctionDoesExist givenDurationIsWithinAllowedDuration {
        wonFinishedAuction();

        vm.prank(sellerOne);
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.WonAuction.selector, 1, bidderOne, amountToDeposit, reservePrice)
        });
        nftAuction.reListItem(1, durationDays, reservePrice);
    }

    function test_RevertWhen_AuctionIsStillOpen(uint256 calledAt)
        external
        givenAuctionDoesExist
        givenDurationIsWithinAllowedDuration
    {
        createAuction(1, durationDays);
        uint256 deadline = block.timestamp + (durationDays * 1 days);

        vm.assume(calledAt < block.timestamp + (durationDays * 1 days));
        vm.warp(calledAt);
        // it should revert
        vm.prank(sellerOne);
        vm.expectRevert({revertData: abi.encodeWithSelector(Errors.AuctionIsStillOpen.selector, deadline)});
        nftAuction.reListItem(1, durationDays, reservePrice);
    }

    function test_GivenSellerMeetsAllConditionsForRelisting()
        external
        givenAuctionDoesExist
        givenDurationIsWithinAllowedDuration
    {
        createAuction(1, durationDays);
        vm.warp(block.timestamp + (durationDays * 1 days) + 1);

        // it should relist the item successfully
        vm.prank(sellerOne);
        vm.expectEmit();
        emit NFTAuction.LogRelistItem(1, block.timestamp + (durationDays * 1 days), reservePrice);
        nftAuction.reListItem(1, durationDays, reservePrice);

        NFTAuction.Auction memory auction = nftAuction.getAuction(1);
        assertEq(uint8(auction.status), 0);
        assertEq(auction.deadline, block.timestamp + (durationDays * 1 days));
        assertEq(auction.reservePrice, reservePrice);
    }
}
