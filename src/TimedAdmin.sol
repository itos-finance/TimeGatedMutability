// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2023 Itos Inc.
pragma solidity ^0.8.0;

import {BaseAdminFacet, AdminLib} from "./Admin.sol";
import {Timed} from "./Timed.sol";

// A base class for admin facets that obey some opinionated time-gating.
abstract contract TimedAdminFacet is BaseAdminFacet {
    /* Required Overrides */

    /// Return the useId to use for Rights in the Timed library.
    /// @param add True if we want to add rights. False if we want to remove them.
    function getRightsUseID(bool add) internal view virtual returns (uint256);

    /// Return the useId to use for ownership in the Timed library.
    function getOwnershipUseID() internal view virtual returns (uint256);

    /// The delay rights have to wait before being accepted.
    function getDelay(uint256 useId) public view virtual returns (uint32);

    /* Ownership related methods */

    /// Time-gated ownership transfer
    function transferOwnership(address _newOwner) external override {
        AdminLib.validateOwner();
        Timed.memoryPrecommit(getOwnershipUseID(), abi.encode(_newOwner));
    }

    /// Time-gated acceptance by the pending owner.
    function acceptOwnership() external {
        uint256 useId = getOwnershipUseID();
        bytes memory entry = Timed.fetchPrecommit(useId, getDelay(useId));
        address newOwner = abi.decode(entry, (address));

        // Do the reassignment
        address oldOwner = AdminLib.reassignOwner(newOwner);
        emit OwnershipTransferred(oldOwner, newOwner);

        // We validate that the person calling is indeed the new owner. This way addresses like 0 can't be owners.
        AdminLib.validateOwner();
    }

    /* Rights related methods */

    /// Submit rights in a Timed way to be accepted at a later time.
    /// @param add True if we want to add these rights. False if we want to remove them.
    function submitRights(address newAdmin, uint256 rights, bool add) external {
        AdminLib.validateOwner();
        Timed.memoryPrecommit(
            getRightsUseID(add),
            abi.encode(newAdmin, rights)
        );
    }

    /// The owner can accept these rights changes.
    function acceptRights() external {
        AdminLib.validateOwner();
        uint256 useId = getRightsUseID(true);
        bytes memory entry = Timed.fetchPrecommit(useId, getDelay(useId));
        (address admin, uint256 newRights) = abi.decode(
            entry,
            (address, uint256)
        );
        AdminLib.register(admin, newRights);
    }

    /// Owner removes admin rights from an address in a time gated manner.
    function removeRights() external {
        AdminLib.validateOwner();
        uint256 useId = getRightsUseID(false);
        bytes memory entry = Timed.fetchPrecommit(useId, getDelay(useId));
        (address admin, uint256 rights) = abi.decode(entry, (address, uint256));
        AdminLib.deregister(admin, rights);
    }

    /// The owner can veto rights additions.
    /// @param add Whether the veto is for an add to rights or a remove.
    function vetoRights(bool add) external {
        AdminLib.validateOwner();
        Timed.deleteEntry(getRightsUseID(add));
    }
}
