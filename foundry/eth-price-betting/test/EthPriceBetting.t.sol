// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {EthPriceBetting} from "../src/EthPriceBetting.sol";
import {MockV3Aggregator} from "../src/mocks/MockV3Aggregator.sol";

contract EthPriceBettingTest is Test {
    EthPriceBetting public ethBet;
    MockV3Aggregator public mock;

    address USER = makeAddr("user");

    function setUp() public {
        mock = new MockV3Aggregator(3000 * 10 ** 8);
        ethBet = new EthPriceBetting{value: 1 ether}(address(mock), 60);

        vm.deal(USER, 1 ether);
    }

    function testDeploy() public view {
        assertEq(address(ethBet).balance, 1 ether);
    }

    function testRevertWhenNotEnoughFunds() public {
        vm.expectRevert("Requires higher amount than 0.2 Ether");
        vm.prank(USER);
        ethBet.createBet{value: 0.1 ether}("long");
    }

    function testRevertWhenAlreadyHaveBet() public {
        vm.startPrank(USER);
        ethBet.createBet{value: 0.3 ether}("long");
        vm.expectRevert("You have existing bet");
        ethBet.createBet{value: 0.3 ether}("long");
        vm.stopPrank();
    }
}
