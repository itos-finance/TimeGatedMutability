// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Terence An <terence@itos.fi>
* Builds upon EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-253
* by Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
/******************************************************************************/
import {IDiamondCut} from "./IDiamondCut.sol";

interface ITimedDiamondCut is IDiamondCut {
    /// A new timed diamond cut has been initiated with these parameters and will take
    /// effect when confirmed after this emitted start time.
    event TimedDiamondCut(
        uint64 indexed startTime,
        uint256 indexed assignmentId,
        FacetCut[] _diamondCut,
        address _init,
        bytes _calldata
    );

    /// Attempted to confirm a cut too early.
    error PrematureCutConfirmation(uint64 confirmTime);
    /// Emitted when the assignmentId doesn't map to any stored cut.
    error CutAssignmentNotFound(uint256 assignmentId);

    /// Identical to diamondCut in every way except it returns the assignmentId so no prefetching is needed.
    /// @dev Useful for contracts who don't need to absolutely adhere to standard Diamond implementation.
    function timedCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external returns (uint256 assignmentId);

    /// The IDiamondCut interface doesn't have a return value so we can't report the assignment ID for a queued
    /// timed cut. Thus callers should prefetch what their assignment will be with this.
    function getNextAssignment() external view returns (uint256);

    /// @notice Accept a previously initiated timed diamond cut now that the delay
    /// has passed.
    function confirmCut(uint256 assignmentId) external;

    /// @notice Reject a previously initiated timed diamond cut.
    function vetoCut(uint256 assignmentId) external;

    /// @notice How much an initialized cut has to wait before it can be confirmed.
    function delay() external view returns (uint32);
}
