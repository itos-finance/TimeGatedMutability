// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {ITimedDiamondCut} from "../src/interfaces/ITimedDiamondCut.sol";

/// Example script for vetoing a cut after initializing it with initCut.s.sol and waiting the required duration.
contract ConfirmCutScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address diamond; // assign to the diamond in question
        uint256 assignmentId; // The assignment ID for the desired cut

        vm.startBroadcast(deployerPrivateKey);

        ITimedDiamondCut(diamond).vetoCut(assignmentId);

        vm.stopBroadcast();
    }
}
