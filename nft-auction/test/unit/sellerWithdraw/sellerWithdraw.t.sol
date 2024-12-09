// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Base_Test } from "test/Base.t.sol";
import { Errors } from "src/utils/Errors.sol";
import { NFTAuction } from "src/NFTAuction.sol";
import { Constants } from "src/utils/Constants.sol";

contract sellerWithdraw_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        vm.prank(sellerOne);
        wonFinishedAuction();
    }

    function test_RevertGiven_AuctionDoesNotExist() external {
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.AuctionDoesNotExist.selector
            )
        });
        nftAuction.sellerWithdraw(2);
    }

    modifier givenAuctionDoesExist() {
        _;
    }

    function test_RevertWhen_SellerIsNotOwnerOfAuction(address user) external givenAuctionDoesExist {
        vm.assume(user != sellerOne);
        vm.prank(user);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.NotOwnerOfAuction.selector
            )
        });
        nftAuction.sellerWithdraw(1);
    }

    function test_RevertWhen_ReservePriceIsNotMet(uint256 amount) external givenAuctionDoesExist {
        vm.prank(sellerOne);
        nftAuction.createAuction(address(nftContract), 2, durationDays, address(daiContract), reservePrice);

        amount = bound({ x: amount, min: 1, max: reservePrice - 1});
        vm.prank(bidderTwo);
        nftAuction.createBid(2, amount);

        vm.warp(block.timestamp + (durationDays * 1 days) + 1 minutes);
        // it should revert
        vm.prank(sellerOne);
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.PriceNotMet.selector,
                reservePrice, amount
            )
        });
        nftAuction.sellerWithdraw(2);
    }

    function test_RevertWhen_AuctionIsStillOpen(uint256 timeAt) external givenAuctionDoesExist {
        vm.prank(sellerOne);
        nftAuction.createAuction(address(nftContract), 2, durationDays, address(daiContract), reservePrice);

        vm.prank(bidderTwo);
        nftAuction.createBid(2, amountToDeposit);

        uint256 deadline = block.timestamp + (durationDays * 1 days);

        vm.assume(timeAt < deadline);
        vm.warp(timeAt);

        // it should revert
        vm.prank(sellerOne);
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.AuctionIsStillOpen.selector,
                deadline
            )
        });
        nftAuction.sellerWithdraw(2);
    }

    function test_RevertWhen_NftIsNotSentToAuctionWinner() external givenAuctionDoesExist {
        vm.prank(sellerOne);
        vm.warp(block.timestamp + (durationDays * 1 days) + 1 minutes);
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.NftNotSent.selector,
                1, bidderOne
            )
        });
        nftAuction.sellerWithdraw(1);
    }

    function test_WhenAuctionWinnerHasReceivedNft() external givenAuctionDoesExist {
        vm.startPrank(sellerOne);
        nftContract.safeTransfer(bidderOne, tokenOne);
        uint256 feeAmount = amountToDeposit * Constants.FEE / 10000;
        uint256 expectedAmount = amountToDeposit - feeAmount;

        // it should deduct fee and withdraw
        vm.expectEmit();
        emit NFTAuction.LogSellerWithdraw(sellerOne, expectedAmount, feeAmount);
        nftAuction.sellerWithdraw(1);

        NFTAuction.Auction memory auction = nftAuction.getAuction(1);
        assertEq(uint8(auction.status), 1);
    }
}
