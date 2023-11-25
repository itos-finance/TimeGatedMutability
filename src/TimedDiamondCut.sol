// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2023 Itos Inc.
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Terence An <terence@itos.fi>
* Builds upon EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-253
* by Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
/******************************************************************************/

import {ITimedDiamondCut} from "./interfaces/ITimedDiamondCut.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";
import {LibDiamond} from "./libraries/LibDiamond.sol";

struct TimedCut {
    ITimedDiamondCut.FacetCut[] cut;
    address init;
    uint64 timestamp;
    bytes initCalldata;
}

/// The Diamond storage used for time gating facet cuts.
struct TimedCutStorage {
    mapping(uint256 => TimedCut) assignments;
    uint256 counter;
}

abstract contract TimedDiamondCutFacet is ITimedDiamondCut {
    bytes32 constant TIMED_DIAMOND_STORAGE_POSITION =
        keccak256("Itos.timed.diamond.cut.20231124");

    /// Get the diamond storage for our cuts.
    function timedCutStorage()
        internal
        pure
        returns (TimedCutStorage storage tcs)
    {
        bytes32 position = TIMED_DIAMOND_STORAGE_POSITION;
        assembly {
            tcs.slot := position
        }
    }

    /* Methods to be overriden */

    /// @inheritdoc ITimedDiamondCut
    /// @dev Any child class of the time delayed diamond cut needs to specify a time delay.
    function delay() public view virtual override returns (uint32);

    /// Validate that the caller has the correct permissions. Revert if incorrect.
    function validateCaller() internal view virtual;

    /// Validate that the caller has the correct veto permissions.
    function validateVeto() internal view virtual;

    /// The diamondCut interface doesn't allow for an assignment id,
    /// so callers should prefetch what their assignment will be.
    function getNextAssignment() external view override returns (uint256) {
        return timedCutStorage().counter + 1;
    }

    /* Implemented methods */

    /// @inheritdoc IDiamondCut
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {
        timedCut(_diamondCut, _init, _calldata);
    }

    /// @inheritdoc ITimedDiamondCut
    function timedCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) public override returns (uint256 assignmentId) {
        validateCaller();

        TimedCutStorage storage tcs = timedCutStorage();
        tcs.counter += 1; // Start at 1
        assignmentId = tcs.counter;

        TimedCut storage tCut = tcs.assignments[assignmentId];
        tCut.init = _init;
        tCut.timestamp = uint64(block.timestamp);
        tCut.initCalldata = _calldata;

        for (uint256 i = 0; i < _diamondCut.length; ++i) {
            tCut.cut.push(_diamondCut[i]);
        }

        emit ITimedDiamondCut.TimedDiamondCut(
            uint64(block.timestamp) + delay(),
            assignmentId,
            _diamondCut,
            _init,
            _calldata
        );
    }

    /// @inheritdoc ITimedDiamondCut
    function confirmCut(uint256 assignmentId) external override {
        validateCaller();
        TimedCutStorage storage tcs = timedCutStorage();
        TimedCut storage tCut = tcs.assignments[assignmentId];

        if (tCut.timestamp == 0)
            revert ITimedDiamondCut.CutAssignmentNotFound(assignmentId);

        // We check the delay now in case it has changed since the install.
        uint64 confirmTime = tCut.timestamp + delay();
        if (uint64(block.timestamp) < confirmTime)
            revert ITimedDiamondCut.PrematureCutConfirmation(confirmTime);

        uint256 length = tCut.cut.length;
        ITimedDiamondCut.FacetCut[]
            memory cuts = new ITimedDiamondCut.FacetCut[](length);
        for (uint256 i = 0; i < length; ++i) {
            cuts[i] = tCut.cut[i];
        }
        LibDiamond.diamondCut(cuts, tCut.init, tCut.initCalldata);

        emit IDiamondCut.DiamondCut(cuts, tCut.init, tCut.initCalldata);

        // We no longer need it. Make sure no reinitialization happens.
        delete tcs.assignments[assignmentId];
    }

    /// @inheritdoc ITimedDiamondCut
    function vetoCut(uint256 assignmentId) external override {
        validateVeto();
        TimedCutStorage storage tcs = timedCutStorage();
        delete tcs.assignments[assignmentId];
    }
}
