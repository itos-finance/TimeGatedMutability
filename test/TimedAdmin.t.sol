// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2023 Itos Inc.
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {PRBTest} from "prb-test/PRBTest.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {TimedAdminFacet} from "../src/TimedAdmin.sol";
import {AdminLib} from "../src/Admin.sol";
import {Timed} from "../src/Timed.sol";

contract TimedTest is PRBTest, StdCheats {
    TestTimedFacet public facet;

    function setUp() public {
        facet = new TestTimedFacet();
    }

    function testTimedAdmin() public {
        facet.submitRights(address(this), 1337, true);
        assertEq(facet.adminRights(address(this)), 0);

        uint256 useId = 0;
        uint256 removeUseId = 1;

        // Can't accept too early
        vm.expectRevert(
            abi.encodeWithSelector(
                Timed.PrematureParamUpdate.selector,
                useId,
                uint64(block.timestamp) + 1,
                uint64(block.timestamp)
            )
        );
        facet.acceptRights();

        // Can't submit another one before accepting this one.
        vm.expectRevert(
            abi.encodeWithSelector(Timed.ExistingPrecommitFound.selector, useId)
        );
        facet.submitRights(address(this), 404, true);

        // Finally accept
        skip(1);
        facet.acceptRights();
        assertEq(facet.adminRights(address(this)), 1337);

        // Submit additional rights
        facet.submitRights(address(this), 2, true);
        skip(1);
        facet.acceptRights();
        assertEq(facet.adminRights(address(this)), 1339);

        // Veto a non-existent remove
        facet.vetoRights(false);
        assertEq(facet.adminRights(address(this)), 1339);

        // accept a non-existent remove
        vm.expectRevert(
            abi.encodeWithSelector(Timed.NoPrecommitFound.selector, removeUseId)
        );
        facet.removeRights();

        // Do a real remove
        facet.submitRights(address(this), 2, false);
        skip(1);
        facet.removeRights();
        assertEq(facet.adminRights(address(this)), 1337);

        // Check another addresss
        assertEq(facet.adminRights(address(facet)), 0);

        // Add it back. Try to reremove.
        facet.submitRights(address(this), 2, true);
        skip(1);
        facet.acceptRights();
        vm.expectRevert(
            abi.encodeWithSelector(Timed.NoPrecommitFound.selector, removeUseId)
        );
        facet.removeRights();

        // Veto real remove.
        facet.submitRights(address(this), 1339, false);
        skip(1);
        facet.vetoRights(false);
        vm.expectRevert(
            abi.encodeWithSelector(Timed.NoPrecommitFound.selector, removeUseId)
        );
        facet.removeRights();

        // Actually remove
        facet.submitRights(address(this), 1339, false);
        skip(1);
        facet.removeRights();
        assertEq(facet.adminRights(address(this)), 0);
    }
}

contract TestTimedFacet is TimedAdminFacet {
    constructor() {
        AdminLib.initOwner(msg.sender);
    }

    function getRightsUseID(bool add) internal pure override returns (uint256) {
        return add ? 0 : 1;
    }

    function getOwnershipUseID() internal pure override returns (uint256) {
        return 2;
    }

    function getDelay(uint256) public pure override returns (uint32) {
        return 1;
    }
}
