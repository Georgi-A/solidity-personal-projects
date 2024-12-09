// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Base_Test } from "test/Base.t.sol";

contract getAccumulatedFees_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        vm.prank(sellerOne);
        succesfullAuction();
        vm.startPrank(owner);
    }

    function test_GetAccumulatedFees() external view {
        uint256 fees = nftAuction.getAccumulatedFees(address(daiContract));
        assertEq(fees, 3e18);
    }
}