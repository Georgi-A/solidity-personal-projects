// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// Auction dependencies
import {Base_Test} from "test/Base.t.sol";

contract getSupportedCurrencies_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
    }

    function test_GetSupportedCurrencies() external view {
        address[] memory currencies = nftAuction.getSupportedCurrencies();
        assertEq(currencies[0], address(daiContract));
        assertEq(currencies[1], address(wethContract));
    }
}
