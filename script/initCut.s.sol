// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {IDiamondCut, ITimedDiamondCut} from "../src/interfaces/ITimedDiamondCut.sol";

/// Example script for updating your contracts.
contract InitCutScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address diamond; // assign to the diamond in question
        address newFacet; // = address(new NewFacet());

        bytes4[] memory functionSelectors = new bytes4[](1);
        // functionSelectors[0] = NewFacet.replacementMethod.selector;
        // ...

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = (
            IDiamondCut.FacetCut({
                facetAddress: newFacet,
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: functionSelectors
            })
        );

        vm.startBroadcast(deployerPrivateKey);
        uint256 assignmentId = ITimedDiamondCut(diamond).timedCut(
            cuts,
            address(0),
            ""
        );
        vm.stopBroadcast();

        console2.log("Cut Assignment", assignmentId);
    }
}
