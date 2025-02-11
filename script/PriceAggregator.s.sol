// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PriceAggregator} from "../src/PriceAggregator.sol";

contract CounterScript is Script {
    PriceAggregator public aggregator;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        aggregator = new PriceAggregator();

        vm.stopBroadcast();
    }
}
