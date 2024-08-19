// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {EthPriceBetting} from "../src/EthPriceBetting.sol";

contract CounterScript is Script {
    EthPriceBetting public counter;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // counter = new EthPriceBetting();

        vm.stopBroadcast();
    }
}
