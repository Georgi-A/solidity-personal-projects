// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// Auction dependencies
import {Base_Test} from "test/Base.t.sol";

contract getOpenAuctions_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
    }

    function test_GetOpenAuctions() external {
        vm.prank(sellerOne);
        createAuction(tokenOne, durationDays);
        vm.prank(sellerOne);
        createAuction(2, durationDays);

        vm.prank(bidderOne);
        uint256[] memory auctions = nftAuction.getOpenAuctions();
        assertEq(auctions[0], 1);
        assertEq(auctions[1], 2);
    }
}
