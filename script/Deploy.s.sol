// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Script} from "forge-std/src/Script.sol";
import {PVP} from "@pvp/PVP.sol";

contract Deploy is Script {
    // Exclude from coverage report
    function test() public {}

    function run() external {
        vm.createSelectFork(vm.envString("SEI_RPC_URL"));
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new PVP();

        vm.stopBroadcast();
    }
}
