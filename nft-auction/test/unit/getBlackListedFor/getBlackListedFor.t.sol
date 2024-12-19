// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// Auction dependencies
import {Base_Test} from "test/Base.t.sol";

contract getBlackListedFor_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        vm.prank(sellerOne);
        wonFinishedAuction();
    }

    function test_GetBlackListedFor() external {
        vm.prank(sellerOne);
        nftContract.safeTransfer(bidderTwo, tokenOne);
        vm.stopPrank();
        vm.prank(bidderOne);
        nftAuction.blackListSeller(1);

        // should return bool and id of auction
        vm.prank(sellerOne);
        (bool blacklisted, uint256 auctionId) = nftAuction.getBlackListedFor();
        assertEq(blacklisted, true);
        assertEq(auctionId, 1);
    }
}
