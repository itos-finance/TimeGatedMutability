// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2023 Itos Inc.
pragma solidity ^0.8.0;

/// @title ERC-173 Contract Ownership Standard
interface IERC173 {
    /// @dev This emits when ownership of a contract changes.
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /// @notice Get the address of the owner
    /// @return The address of the owner.
    function owner() external view returns (address);

    /// @notice Set the address of the new owner of the contract
    /// @dev Set _newOwner to address(0) to renounce any ownership.
    /// @param _newOwner The address of the new owner of the contract
    function transferOwnership(address _newOwner) external;
}

/// These are flags that can be joined so each is assigned its own hot bit.
/// Users should make more flags in their own library.
/// @dev These flags get the very top bits so that user specific flags are given the lower bits.
library AdminFlags {
    uint256 public constant NULL = 0; // No clearance at all. Default value.
    uint256 public constant OWNER =
        0x8000000000000000000000000000000000000000000000000000000000000000;
    uint256 public constant VETO =
        0x4000000000000000000000000000000000000000000000000000000000000000;
}

struct AdminRegistry {
    // The owner actually does not have any rights except the ability to assign rights to users.
    // Of course it can assign rights to itself.
    // Thus it is probably desireable to qualify this ability, for example by time-gating it.
    address owner;
    // Rights are one hot encodings of permissions granted to users.
    // Each right should be a single bit in the uint256.
    mapping(address => uint256) rights;
}

/**
 * @title Administrative Library
 * @author Terence An
 * @notice This contains an administrative utility that uses diamond storage.
 * This is used to add and remove administrative privileges from addresses.
 * It also has validation functions for those privileges.
 * @dev It is recommended to use these utilities behind veto-able time-gating.
 **/
library AdminLib {
    bytes32 constant ADMIN_STORAGE_POSITION =
        keccak256("Itos.admin.diamond.storage.20231124");

    error NotOwner();
    error InsufficientCredentials(
        address caller,
        uint256 expectedRights,
        uint256 actualRights
    );
    error CannotReinitializeOwner(address existingOwner);
    error ImproperOwnershipAcceptance();

    event AdminAdded(address admin, uint256 newRight, uint256 existing);
    event AdminRemoved(address admin, uint256 removedRight, uint256 existing);

    function adminStore() internal pure returns (AdminRegistry storage adReg) {
        bytes32 position = ADMIN_STORAGE_POSITION;
        assembly {
            adReg.slot := position
        }
    }

    /* Getters */

    function getOwner() external view returns (address) {
        return adminStore().owner;
    }

    // @return lvl Will be cast to uint8 on return to external contracts.
    function getAdminRights(
        address addr
    ) external view returns (uint256 rights) {
        return adminStore().rights[addr];
    }

    /* Validating Helpers */

    function validateOwner() internal view {
        if (msg.sender != adminStore().owner) {
            revert NotOwner();
        }
    }

    /// Revert if the msg.sender does not have the expected right.
    function validateRights(uint256 expected) internal view {
        AdminRegistry storage adReg = adminStore();
        uint256 actual = adReg.rights[msg.sender];
        if (actual & expected != expected) {
            revert InsufficientCredentials(msg.sender, expected, actual);
        }
    }

    /* Registry functions */

    /// Called when there is no owner so one can be set for the first time.
    function initOwner(address owner) internal {
        AdminRegistry storage adReg = adminStore();
        if (adReg.owner != address(0))
            revert CannotReinitializeOwner(adReg.owner);
        adReg.owner = owner;
    }

    /// Move ownership to another address.
    /// @dev Remember to validate any functions calling this method.
    /// @return oldOwner The previous owner.
    function reassignOwner(
        address newOwner
    ) internal returns (address oldOwner) {
        AdminRegistry storage adReg = adminStore();
        oldOwner = adReg.owner;
        adReg.owner = newOwner;
    }

    /// Add a right to an address
    /// @dev When actually using, the importing function should add restrictions to this.
    function register(address admin, uint256 right) internal {
        AdminRegistry storage adReg = adminStore();
        uint256 existing = adReg.rights[admin];
        adReg.rights[admin] = existing | right;
        emit AdminAdded(admin, right, existing);
    }

    /// Remove a right from an address.
    /// @dev When using, the wrapper function should add restrictions.
    function deregister(address admin, uint256 right) internal {
        AdminRegistry storage adReg = adminStore();
        uint256 existing = adReg.rights[admin];
        adReg.rights[admin] = existing & (~right);
        emit AdminRemoved(admin, right, existing);
    }
}

/// Base class for an admin facet. Utilizes the AdminLib.
contract BaseAdminFacet is IERC173 {
    /// @notice Transfer ownership to another address.
    /// @dev It is recommended to override this method with additional features like
    /// time-gating or new owners must accept ownership first. See TimedAdmin for proper usage.
    function transferOwnership(address _newOwner) external virtual override {
        AdminLib.validateOwner();
        AdminLib.reassignOwner(_newOwner);
        emit OwnershipTransferred(msg.sender, _newOwner);
    }

    function owner() external view override returns (address owner_) {
        owner_ = AdminLib.getOwner();
    }

    /// Fetch the admin level for an address.
    function adminRights(address addr) external view returns (uint256 rights) {
        return AdminLib.getAdminRights(addr);
    }
}
