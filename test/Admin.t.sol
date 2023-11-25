// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2023 Itos Inc.
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {PRBTest} from "prb-test/PRBTest.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {AdminLib, BaseAdminFacet} from "../src/Admin.sol";

contract AdminTest is PRBTest, StdCheats {
    function setUp() public {
        AdminLib.initOwner(msg.sender);
    }

    function requireValidation(uint256 right) external view {
        AdminLib.validateRights(right);
    }

    function testOwner() public {
        assertEq(AdminLib.getOwner(), msg.sender);
        AdminLib.validateOwner();

        // But the owner doesn't start with any rights.
        uint256 testRights = 8;
        vm.expectRevert(
            abi.encodeWithSelector(
                AdminLib.InsufficientCredentials.selector,
                msg.sender,
                testRights,
                0
            )
        );
        AdminLib.validateRights(testRights);

        // But once we give it rights it's okay.
        AdminLib.register(msg.sender, testRights);
        AdminLib.validateRights(testRights);

        // But using a different right will fail.
        uint256 testRights2 = 4;
        vm.expectRevert(
            abi.encodeWithSelector(
                AdminLib.InsufficientCredentials.selector,
                msg.sender,
                testRights2,
                testRights
            )
        );
        AdminLib.validateRights(testRights2);

        // And if we deregister even the orgiinal will fail.
        AdminLib.deregister(msg.sender, testRights);
        vm.expectRevert(
            abi.encodeWithSelector(
                AdminLib.InsufficientCredentials.selector,
                msg.sender,
                testRights,
                0
            )
        );
        AdminLib.validateRights(testRights);

        // We can't reinitialize
        vm.expectRevert(
            abi.encodeWithSelector(
                AdminLib.CannotReinitializeOwner.selector,
                msg.sender
            )
        );
        AdminLib.initOwner(address(this));

        // But we can reassign
        AdminLib.reassignOwner(address(this));

        // Verify we're not the owner anymore
        vm.expectRevert(AdminLib.InsufficientCredentials.selector);
        AdminLib.validateOwner();

        assertEq(AdminLib.getOwner(), address(this));
    }

    // Call into this contract using an external contract to see that it gets
    // validated properly.
    function testRegistration() public {
        AdminTestHelper helper = new AdminTestHelper(this);

        assertEq(AdminLib.getAdminRights(address(helper)), 0);

        AdminLib.register(address(helper), 2);
        assertEq(AdminLib.getAdminRights(address(helper)), 2);
        helper.validateAs(2);

        vm.expectRevert(
            abi.encodeWithSelector(
                AdminLib.InsufficientCredentials.selector,
                address(helper),
                1,
                2
            )
        );

        helper.validateAs(1);

        // We can add more rights.
        AdminLib.register(address(helper), 1);
        assertEq(AdminLib.getAdminRights(address(helper)), 3);
        helper.validateAs(3);
        helper.validateAs(2);
        helper.validateAs(1);

        AdminLib.deregister(address(helper), 2);
        helper.validateAs(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                AdminLib.InsufficientCredentials.selector,
                address(helper),
                2,
                1
            )
        );
        helper.validateAs(2);
        vm.expectRevert(
            abi.encodeWithSelector(
                AdminLib.InsufficientCredentials.selector,
                address(helper),
                3,
                1
            )
        );
        helper.validateAs(3);

        assertEq(AdminLib.getAdminRights(address(helper)), 1);
    }

    function testBaseAdminFacet() public {
        AdminFacet adminFacet = new AdminFacet();
        assertEq(adminFacet.owner(), address(this));
        assertEq(adminFacet.adminRights(address(this)), 0);

        address rando = address(0x1337);

        vm.startPrank(rando);
        vm.expectRevert(AdminLib.NotOwner.selector);
        adminFacet.transferOwnership(address(0));
        vm.stopPrank();

        adminFacet.transferOwnership(rando);
        assertEq(adminFacet.owner(), rando);

        vm.startPrank(rando);
        adminFacet.transferOwnership(address(0));
        vm.stopPrank();
    }
}

contract AdminTestHelper {
    AdminTest public tester;

    constructor(AdminTest _tester) {
        tester = _tester;
    }

    function validateAs(uint8 num) public view {
        tester.requireValidation(num);
    }
}

contract AdminFacet is BaseAdminFacet {
    constructor() {
        AdminLib.initOwner(msg.sender);
    }
}
