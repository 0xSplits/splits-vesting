// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import {VestingModule} from "./VestingModule.sol";
import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";

/// @dev this contract uses address(0) in some events & mappings to refer to eth

contract VestingModuleFactory {
    /// -----------------------------------------------------------------------
    /// errors
    /// -----------------------------------------------------------------------

    error InvalidBeneficiary();
    error InvalidVestingPeriod();

    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------

    using ClonesWithImmutableArgs for address;

    /// -----------------------------------------------------------------------
    /// events
    /// -----------------------------------------------------------------------

    /// @notice New vesting integration contract deployed
    /// @param beneficiary Address to receive funds after vesting
    /// @param vestingPeriod Period of time for funds to vest
    event CreateVestingModule(
        address indexed beneficiary,
        uint256 vestingPeriod
    );

    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    VestingModule public implementation;

    /// -----------------------------------------------------------------------
    /// constructor
    /// -----------------------------------------------------------------------

    // TODO: deploy VestingModule in constructor or pass as arg?
    /* constructor(VestingModule implementation_) { */
    /*     implementation = implementation_; */
    /* } */
    constructor() {
        implementation = new VestingModule();
    }

    /// -----------------------------------------------------------------------
    /// functions
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - public & external
    /// -----------------------------------------------------------------------

    /// @notice Creates new vesting module
    /// @param beneficiary Address to receive funds after vesting
    /// @param vestingPeriod Period of time for funds to vest
    function createVestingModule(address beneficiary, uint256 vestingPeriod)
        external
        returns (VestingModule vm)
    {
        /// checks
        if (beneficiary == address(0)) revert InvalidBeneficiary();
        if (vestingPeriod == 0) revert InvalidVestingPeriod();

        /// effects
        bytes memory data = abi.encodePacked(beneficiary, vestingPeriod);
        vm = VestingModule(address(implementation).clone(data));
        emit CreateVestingModule(beneficiary, vestingPeriod);
    }
}
