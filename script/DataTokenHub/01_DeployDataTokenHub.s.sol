// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "../../contracts/upgradeability/ERC1967Proxy.sol";
import {DataTokenHub} from "../../contracts/DataTokenHub.sol";
import {Config} from "../Config.sol";

contract DeployDataTokenHub is Script, Config {
    function run() public returns (address) {
        _privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(_privateKey);
        DataTokenHub dataTokenHub = new DataTokenHub();
        ERC1967Proxy dataTokenHubProxy = new ERC1967Proxy(address(dataTokenHub), new bytes(0));
        DataTokenHub(address(dataTokenHubProxy)).initialize();
        vm.stopBroadcast();

        return address(dataTokenHubProxy);
    }
}
