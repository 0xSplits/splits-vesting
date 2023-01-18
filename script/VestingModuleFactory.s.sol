// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {VestingModuleFactory} from "src/VestingModuleFactory.sol";

contract VestingModuleFactoryScript is Script {
    function run() external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privKey);

        new VestingModuleFactory();

        vm.stopBroadcast();
    }
}
