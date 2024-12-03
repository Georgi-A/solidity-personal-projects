// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Base_Test} from "test/Base.t.sol";
import {Errors} from "src/utils/Errors.sol";
import {NFTAuction} from "src/NFTAuction.sol";

contract sellerWithdraw_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        wonFinishedAuction();
        vm.startPrank(sellerOne);
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

    function test_RevertWhen_SellerIsNotOwnerOfAuction() external givenAuctionDoesExist {
        vm.stopPrank();
        vm.startPrank(sellerTwo);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.NotOwnerOfAuction.selector
            )
        });
        nftAuction.sellerWithdraw(1);
    }

    function test_RevertWhen_ReservePriceIsNotMet() external givenAuctionDoesExist {
        nftAuction.createAuction(address(nftContract), 2, durationDays, address(daiContract), reservePrice);

        vm.warp(block.timestamp + (durationDays * 1 days) + 1 minutes);
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.PriceNotMet.selector,
                reservePrice, 0
            )
        });
        nftAuction.sellerWithdraw(2);
    }

    function test_RevertWhen_AuctionIsStillOpen() external givenAuctionDoesExist {
        nftAuction.createAuction(address(nftContract), 2, durationDays, address(daiContract), reservePrice);

        vm.startPrank(bidderTwo);
        nftAuction.createBid(2, amountToDeposit);
        vm.stopPrank();

        // it should revert
        vm.startPrank(sellerOne);
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.AuctionIsStillOpen.selector,
                block.timestamp + (durationDays * 1 days)
            )
        });
        nftAuction.sellerWithdraw(2);
    }

    function test_RevertWhen_NftIsNotYetSentToAuctionWinner() external givenAuctionDoesExist {
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
        
    }
}
