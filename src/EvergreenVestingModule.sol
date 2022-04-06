// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

// TODO: add events
// TODO: update tests
// TODO: add erc20 support
// TODO: update tests
// TODO: convert to factory/clone
// TODO: update tests
// TODO: rename? VestingModule?
// TODO: leave 1s for efficiency?
// TODO: unchecked?

contract EvergreenVestingModule {
    /// -----------------------------------------------------------------------
    /// errors
    /// -----------------------------------------------------------------------

    error InvalidBeneficiary();

    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------

    using SafeTransferLib for address;
    /* using SafeTransferLib for ERC20; */

    /// -----------------------------------------------------------------------
    /// events
    /// -----------------------------------------------------------------------

    /// @notice New vesting integration contract deployed
    /// @param beneficiary Address to receive funds after vesting
    /// @param vestingPeriod Period of time for funds to vest
    event CreateEvergreenVestingModule(
        address indexed beneficiary,
        uint256 vestingPeriod
    );

    /// -----------------------------------------------------------------------
    /// structs
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// constants
    /// -----------------------------------------------------------------------

    uint256 constant DEFAULT_VESTING_PERIOD = 365 days;

    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    /// Address to receive funds after vesting
    address public immutable beneficiary;
    /// Period of time for funds to vest (defaults to 365 days)
    uint256 public immutable vestingPeriod;

    /// Timestamp of last vesting start
    uint256 public vestingStart;
    /// Amount vesting
    uint256 public vesting;
    /// Amount of current vest claimed
    uint256 public vestingClaimed;
    /// Amount previously vested & waiting to be claimed
    uint256 public toBeClaimed;

    /// -----------------------------------------------------------------------
    /// constructor
    /// -----------------------------------------------------------------------

    /// @param _beneficiary Address to receive funds after vesting
    /// @param _vestingPeriod Period of time for funds to vest
    constructor(address _beneficiary, uint256 _vestingPeriod) {
        ///
        /// checks
        ///
        if (_beneficiary == address(0)) revert InvalidBeneficiary();

        ///
        /// effects
        ///
        beneficiary = _beneficiary;
        vestingPeriod = (_vestingPeriod != 0)
            ? _vestingPeriod
            : DEFAULT_VESTING_PERIOD;

        emit CreateEvergreenVestingModule(beneficiary, vestingPeriod);
    }

    /// -----------------------------------------------------------------------
    /// functions
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - public & external
    /// -----------------------------------------------------------------------

    /// @notice receive ETH
    receive() external payable {
        // TODO: emit event
    }

    // TODO: if using the leave-1 pattern, might wish to use internal variables
    // with custom views
    // TODO: needs some kind of anti-griefing mechanism

    //  TODO: rename to EvergreenVest or Stream or something & revamp for pg's needs

    /// @notice begins vesting on available ETH
    function addToVest() external payable {
        ///
        /// checks
        ///

        ///
        /// effects
        ///

        toBeClaimed += _newlyVestedAndUnclaimed();
        vesting = address(this).balance - toBeClaimed;
        /* vestingClaimed = 1; */
        vestingClaimed = 0;
        vestingStart = block.timestamp;

        // TODO: emit event

        ///
        /// interactions
        ///
    }

    /// @notice claims vested ETH for the beneficiary
    function claimFromVest() external payable {
        ///
        /// checks
        ///

        ///
        /// effects
        ///

        uint256 fundsToSend = _newlyVestedAndUnclaimed();
        vestingClaimed += fundsToSend;

        /* if (toBeClaimed > 1) { */
        /*     fundsToSend += (toBeClaimed - 1); */
        /*     toBeClaimed = 1; */
        /* } */
        if (toBeClaimed > 0) {
            fundsToSend += toBeClaimed;
            toBeClaimed = 0;
        }

        // TODO: emit event

        ///
        /// interactions
        ///
        beneficiary.safeTransferETH(fundsToSend);
    }

    /// -----------------------------------------------------------------------
    /// functions - views
    /// -----------------------------------------------------------------------

    /// @notice returns amount vested & unclaimed
    /// @return amount vested & unclaimed
    function vestedAndUnclaimed() external view returns (uint256) {
        return
            /* (toBeClaimed > 1 ? toBeClaimed - 1 : toBeClaimed) + */
            toBeClaimed + _newlyVestedAndUnclaimed();
    }

    /// -----------------------------------------------------------------------
    /// functions - private & internal
    /// -----------------------------------------------------------------------

    /// @notice returns amount vested & unclaimed within the current vesting period
    /// @return amount vested & unclaimed within the current vesting period
    function _newlyVestedAndUnclaimed() internal view returns (uint256) {
        return
            (
                (block.timestamp >= vestingStart + vestingPeriod)
                    ? vesting // TODO: use FullMath? // e.g. https://github.com/ZeframLou/vested-erc20/blob/main/src/lib/FullMath.sol
                    : (vesting * (block.timestamp - vestingStart)) /
                        vestingPeriod
                /* ) - ((vestingClaimed > 0) ? vestingClaimed - 1 : 0); */
            ) - vestingClaimed;
    }
}
