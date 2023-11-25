// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2023 Itos Inc.
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {PRBTest} from "prb-test/PRBTest.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {TimedDiamondCutFacet} from "../src/TimedDiamondCut.sol";
import {ITimedDiamondCut} from "../src/interfaces/ITimedDiamondCut.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {Diamond} from "../src/libraries/Diamond.sol";
import {LibDiamond} from "../src/libraries/LibDiamond.sol";

// Shared storage utility contract.
contract Storer {
    bytes32 public constant TEST_DIAMOND_STORAGE_POSITION = keccak256("test");

    // Storage needed by the delegate calls
    struct Storage {
        // Used by TestCutFacet
        address approvedCaller;
        address approvedVetoer;
        // Used by TestFacet
        uint256 ret;
    }

    /* Storage utilities for delegate calling. */

    function getStorage() internal pure returns (Storage storage s) {
        bytes32 position = TEST_DIAMOND_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function setStorage(address caller, address vetoer) external {
        Storage storage s = getStorage();
        s.approvedCaller = caller;
        s.approvedVetoer = vetoer;
    }
}

contract TestFacet is Storer {
    function isInstalled() external view returns (uint256) {
        return getStorage().ret;
    }
}

contract Initer is Storer {
    function init(uint256 _ret) external {
        getStorage().ret = _ret;
    }
}

contract TestCutFacet is TimedDiamondCutFacet, Storer {
    error BadCaller();
    error BadVeto();

    /* Abstract functions to fill in. These are DELEGATECALL'd into. */

    function delay() public pure override returns (uint32) {
        return 1;
    }

    function validateCaller() internal view override {
        if (msg.sender != getStorage().approvedCaller) revert BadCaller();
    }

    function validateVeto() internal view override {
        if (msg.sender != getStorage().approvedVetoer) revert BadVeto();
    }
}

contract TestDiamond is Diamond {
    constructor(
        address _contractOwner,
        address _diamondCutFacet
    ) payable Diamond(_contractOwner, _diamondCutFacet) {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0].facetAddress = _diamondCutFacet;
        cuts[0].action = IDiamondCut.FacetCutAction.Add;

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = ITimedDiamondCut.timedCut.selector;
        selectors[1] = ITimedDiamondCut.confirmCut.selector;
        selectors[2] = ITimedDiamondCut.vetoCut.selector;
        selectors[3] = Storer.setStorage.selector;
        cuts[0].functionSelectors = selectors;

        LibDiamond.diamondCut(cuts, address(0), "");
    }
}

contract TimedDiamondCutTest is PRBTest, StdCheats {
    address public diamond;
    TestCaller public caller;

    function setUp() public {
        address cutFacet = address(new TestCutFacet());
        diamond = address(new TestDiamond(address(this), cutFacet));

        caller = new TestCaller(diamond);
    }

    /// Test that only an approved caller can make the cut
    /// and accept at the approved time.
    function testTimedCut() public {
        // No approved caller is set yet, we should fail.
        vm.expectRevert(TestCutFacet.BadCaller.selector);
        caller.callCut(1337, IDiamondCut.FacetCutAction.Add);

        TestCutFacet(diamond).setStorage(address(caller), address(0));

        // Calling an assignment that isn't installed yet.
        vm.expectRevert(
            abi.encodeWithSelector(
                ITimedDiamondCut.CutAssignmentNotFound.selector,
                uint256(1)
            )
        );
        caller.callConfirm(1);

        // Now install a facet that returns 1337
        uint256 assignmentId = caller.callCut(
            1337,
            IDiamondCut.FacetCutAction.Add
        );
        // Check the installation doesn't exist yet.
        vm.expectRevert();
        TestFacet(diamond).isInstalled();
        // We can't confirm it yet.
        vm.expectRevert(
            abi.encodeWithSelector(
                ITimedDiamondCut.PrematureCutConfirmation.selector,
                uint64(block.timestamp + 1)
            )
        );
        caller.callConfirm(assignmentId);
        vm.warp(block.timestamp + 1);
        // Now we can confirm it.
        caller.callConfirm(assignmentId);
        assertEq(TestFacet(diamond).isInstalled(), 1337);

        // We can't reconfirm.
        vm.expectRevert(
            abi.encodeWithSelector(
                ITimedDiamondCut.CutAssignmentNotFound.selector,
                assignmentId
            )
        );
        caller.callConfirm(assignmentId);

        // Now replace.
        caller.newFacet(); // Can't replace with the same address so use a new one.
        assignmentId = caller.callCut(777, IDiamondCut.FacetCutAction.Replace);
        vm.warp(block.timestamp + 1);
        // Not replaced yet.
        assertEq(TestFacet(diamond).isInstalled(), 1337);

        // And if we're not the caller, we can't confirm.
        TestCutFacet(diamond).setStorage(address(0), address(0));
        vm.expectRevert(TestCutFacet.BadCaller.selector);
        caller.callConfirm(assignmentId);

        // Now we can finally replace.
        TestCutFacet(diamond).setStorage(address(caller), address(0));
        caller.callConfirm(assignmentId);
        // And we get the new result from the new facet.
        assertEq(TestFacet(diamond).isInstalled(), 777);

        // Now remove.
        assignmentId = caller.removeLast();
        // Not removed yet.
        assertEq(TestFacet(diamond).isInstalled(), 777);
        vm.warp(block.timestamp + 1);
        caller.callConfirm(assignmentId);
        // Now its gone.
        vm.expectRevert();
        TestFacet(diamond).isInstalled();
    }

    function testCutVeto() public {
        TestCutFacet(diamond).setStorage(address(caller), address(0));
        uint256 assignmentId = caller.callCut(
            1337,
            IDiamondCut.FacetCutAction.Add
        );
        vm.expectRevert(TestCutFacet.BadVeto.selector);
        caller.callVeto(assignmentId);

        TestCutFacet(diamond).setStorage(address(caller), address(caller));
        caller.callVeto(assignmentId);
        // trying to confirm it after fails.
        vm.expectRevert(
            abi.encodeWithSelector(
                ITimedDiamondCut.CutAssignmentNotFound.selector,
                assignmentId
            )
        );
        caller.callConfirm(assignmentId);
    }
}

/// Test contract that calls the cut/confirm/veto functionality on our diamond contract.
contract TestCaller {
    ITimedDiamondCut public test;

    TestFacet public facet;
    Initer public init;

    constructor(address _test) {
        test = ITimedDiamondCut(_test);
        facet = new TestFacet();
        init = new Initer();
    }

    // Can't replace the facet with the same address so make a new one.
    function newFacet() external {
        facet = new TestFacet();
    }

    /// Does a cut with the TestFacet's isinstalled function. Modifies the contract's storage with ret as well.
    function callCut(
        uint256 ret,
        IDiamondCut.FacetCutAction action
    ) external returns (uint256) {
        ITimedDiamondCut.FacetCut[]
            memory cut = new ITimedDiamondCut.FacetCut[](1);
        cut[0].facetAddress = address(facet);
        cut[0].action = action;
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TestFacet.isInstalled.selector;
        cut[0].functionSelectors = selectors;

        // Does the cut and initializes the storage with the ret value we want.
        bytes memory args = abi.encodeWithSelector(Initer.init.selector, ret);
        return test.timedCut(cut, address(init), args);
    }

    // Removes the isInstalled function selector.
    function removeLast() external returns (uint256) {
        ITimedDiamondCut.FacetCut[]
            memory cut = new ITimedDiamondCut.FacetCut[](1);
        cut[0].facetAddress = address(0);
        cut[0].action = IDiamondCut.FacetCutAction.Remove;
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TestFacet.isInstalled.selector;
        cut[0].functionSelectors = selectors;

        return test.timedCut(cut, address(0), "");
    }

    function callConfirm(uint256 assignmentId) external {
        test.confirmCut(assignmentId);
    }

    function callVeto(uint256 assignmentId) external {
        test.vetoCut(assignmentId);
    }
}
