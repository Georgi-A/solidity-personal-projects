// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// Auction dependencies
import {Base_Test} from "test/Base.t.sol";
import {Errors} from "src/utils/Errors.sol";
import {Constants} from "src/utils/Constants.sol";
import {NFTAuction} from "src/NFTAuction.sol";

contract CreateAuction_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();

        vm.startPrank(sellerOne);
    }

    function testFuzz_Given_RevertTheDurationIsLessThanMinDuration(uint256 duration) external {
        vm.assume(duration < Constants.MIN_DURATION);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.AuctionDurationOutOfBounds.selector, Constants.MIN_DURATION, Constants.MAX_DURATION
            )
        });
        nftAuction.createAuction(address(nftContract), tokenOne, duration, address(daiContract), reservePrice);
    }

    function testFuzz_Given_RevertTheDurationIsHigherThanMaxDuration(uint256 duration) external {
        vm.assume(duration > Constants.MAX_DURATION && duration < 1000);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.AuctionDurationOutOfBounds.selector, Constants.MIN_DURATION, Constants.MAX_DURATION
            )
        });
        nftAuction.createAuction(address(nftContract), tokenOne, duration, address(daiContract), reservePrice);
    }

    function testFuzz_Given_RevertTheSellerIsNotOwnerOfTokenID(uint256 tokenId) external {
        vm.assume(tokenId > 3);
        nftContract.mint(sellerOne, tokenId);
        vm.stopPrank();
        vm.startPrank(sellerTwo);
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.NotOwnerOfToken.selector, nftContract.ownerOf(tokenId))
        });
        nftAuction.createAuction(address(nftContract), tokenId, durationDays, address(daiContract), reservePrice);
    }

    function testFuzz_When_RevertTheTokenIsAlreadyListed(uint256 tokenId) external {
        vm.assume(tokenId > 3);
        nftContract.mint(sellerOne, tokenId);
        nftAuction.createAuction(address(nftContract), tokenId, durationDays, address(daiContract), reservePrice);
        // it should revert
        vm.expectRevert({revertData: abi.encodeWithSelector(Errors.ItemAlreadyListed.selector)});
        nftAuction.createAuction(address(nftContract), tokenId, durationDays, address(daiContract), reservePrice);
    }

    function test_Given_RevertReservePriceIsZero() external {
        // it should revert
        vm.expectRevert({revertData: abi.encodeWithSelector(Errors.ZeroInput.selector)});
        nftAuction.createAuction(address(nftContract), tokenOne, durationDays, address(daiContract), 0);
    }

    function testFuzz_Given_RevertCurrencyIsNotAllowed(address currency) external {
        vm.assume(currency != address(daiContract) && currency != address(wethContract));
        // it should revert
        vm.expectRevert({revertData: abi.encodeWithSelector(Errors.CurrencyNotSupported.selector)});
        nftAuction.createAuction(address(nftContract), tokenOne, durationDays, currency, reservePrice);
    }

    function testFuzz_RevertWhen_SellerHasBeenBlacklisted(uint256 duration) external {
        nftAuction.createAuction(address(nftContract), tokenOne, durationDays, address(daiContract), reservePrice);

        vm.startPrank(bidderOne);
        nftAuction.createBid(1, toDecimals(250));
        uint256 sendNftDeadline = block.timestamp + (5 days);
        vm.assume(duration > sendNftDeadline);
        vm.warp(duration);
        nftAuction.blackListSeller(1);

        // it should revert
        vm.startPrank(sellerOne);
        vm.expectRevert({revertData: abi.encodeWithSelector(Errors.BlackListed.selector, 1)});
        nftAuction.createAuction(address(nftContract), 2, durationDays, address(daiContract), reservePrice);
    }

    function test_WhenTokenIsSoldAndListedAgain() external {
        vm.expectEmit();
        emit NFTAuction.LogCreateAuction(address(sellerOne), address(nftContract), tokenOne, block.timestamp + 4 days);
        nftAuction.createAuction(address(nftContract), tokenOne, durationDays, address(daiContract), reservePrice);

        vm.startPrank(bidderOne);
        nftAuction.createBid(1, toDecimals(250));

        vm.warp(block.timestamp + 4 days + 1 minutes);

        vm.startPrank(sellerOne);
        nftContract.safeTransfer(bidderOne, tokenOne);

        // it should create auction
        vm.startPrank(bidderOne);
        vm.expectEmit();
        emit NFTAuction.LogCreateAuction(address(bidderOne), address(nftContract), tokenOne, block.timestamp + 4 days);
        nftAuction.createAuction(address(nftContract), tokenOne, durationDays, address(wethContract), reservePrice);
    }

    function test_GivenAllParametersAreValid() external {
        // it should create auction
        vm.expectEmit();
        emit NFTAuction.LogCreateAuction(address(sellerOne), address(nftContract), 1, block.timestamp + 4 days);
        nftAuction.createAuction(address(nftContract), tokenOne, durationDays, address(daiContract), reservePrice);
        NFTAuction.Auction memory auction = nftAuction.getAuction(1);

        assertEq(auction.auctionId, 1);
        assertEq(auction.collectionContract, address(nftContract));
        assertEq(auction.tokenId, tokenOne);
        assertEq(auction.seller, sellerOne);
        assertEq(auction.deadline, block.timestamp + (durationDays * 1 days));
        assertEq(auction.currency, address(daiContract));
        assertEq(auction.reservePrice, reservePrice);
        assertEq(uint8(NFTAuction.Status.OPEN), 0);
    }
}
