// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

// TODO: convert to factory/clone
// TODO: update tests

// TODO: header
/// @dev this contract uses address(0) in some mappings to refer to eth

contract VestingModule {
    /// -----------------------------------------------------------------------
    /// errors
    /// -----------------------------------------------------------------------

    error InvalidBeneficiary();
    error InvalidVestingStreamId(uint256 id);

    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------

    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

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

    // TODO: do we need timestamp in this event? FE could pull TS from tx/block
    // since vestingStart always = block.timestamp
    /// @notice New vesting stream created
    /// @param id Id of vesting stream
    /// @param token Address of token to vest (0x0 for eth)
    /// @param vestingStart Starting timestamp of vesting stream
    /// @param amount Amount to vest
    event CreateVestingStream(
        uint256 indexed id,
        address indexed token,
        uint256 vestingStart,
        uint256 amount
    );

    // TODO: do we need a token or timestamp in this event?
    /// @notice Release from vesting stream
    /// @param id Id of vesting stream
    /// @param amount Amount released from stream
    event ReleaseFromVestingStream(uint256 indexed id, uint256 amount);

    /// @notice Emitted after each successful ETH transfer to proxy
    /// @param amount Amount of ETH received
    event ReceiveETH(uint256 amount);

    /// -----------------------------------------------------------------------
    /// structs
    /// -----------------------------------------------------------------------

    /// @notice holds vesting stream metadata
    struct VestingStream {
        address token;
        uint256 vestingStart;
        uint256 total;
        uint256 released;
    }

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

    /// Number of vesting streams
    /// @dev Used for sequential ids
    uint256 public numVestingStreams;

    // TODO: add accessor methods
    /// Mapping from Id to vesting stream
    mapping(uint256 => VestingStream) internal vestingStreams;
    /// Mapping from token to amount vesting (includes current & previous)
    mapping(address => uint256) public vesting;
    /// Mapping from token to amount released
    mapping(address => uint256) public released;

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

        emit CreateVestingModule(beneficiary, vestingPeriod);
    }

    /// -----------------------------------------------------------------------
    /// functions
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - public & external
    /// -----------------------------------------------------------------------

    /// @notice receive ETH
    receive() external payable {
        emit ReceiveETH(msg.value);
    }

    /// @notice Creates new vesting streams
    /// @notice tokens Addresses of ETH (0x0) & ERC20s to create vesting streams for
    function createVestingStream(address[] calldata tokens) external payable {
        // use count as first new sequential id
        uint256 vestingStreamId = numVestingStreams;

        unchecked {
            uint256 numTokens = tokens.length;
            // overflow should be impossible in for-loop index
            for (uint256 i = 0; i < numTokens; ++i) {
                address token = tokens[i];
                // overflow should be impossible
                // shouldn't need to worry about re-entrancy from ERC20 view fn
                // recognizes 0x0 as eth
                uint256 pendingAmount = (
                                         token != address(0)
                                         ? ERC20(token).balanceOf(address(this))
                        : address(this).balance
                ) +
                    released[token] -
                    vesting[token];
                vesting[token] += pendingAmount;
                // overflow should be impossible
                // TODO: test gas efficiency vs incrementing vestingStreamId on its own in loop
                // TODO: test gas efficiency of setting individually?
                vestingStreams[vestingStreamId + i] = VestingStream({
                    token: token,
                    vestingStart: block.timestamp,
                    total: pendingAmount,
                    released: 0
                });
                emit CreateVestingStream(
                    vestingStreamId,
                    token,
                    block.timestamp,
                    pendingAmount
                );
            }
            // use last created id as new count
            // overflow should be impossible
            numVestingStreams = vestingStreamId + numTokens;
        }
    }

    /// @notice Releases vested funds to the beneficiary
    /// @notice ids Ids of vesting streams to release funds from
    function releaseFromVest(uint256[] calldata ids) external payable {
        unchecked {
            uint256 numIds = ids.length;
            // overflow should be impossible in for-loop index
            for (uint256 i = 0; i < numIds; ++i) {
                uint256 id = ids[i];
                if (id >= numVestingStreams) revert InvalidVestingStreamId(id);
                // TODO: test gas of storage or calldata
                VestingStream memory vs = vestingStreams[id];
                // underflow should be impossible
                uint256 elapsedTime = block.timestamp - vs.vestingStart;
                // TODO: use FullMath?
                // TODO: do I need to be concerned about overflow here? don't think so..
                uint256 vested = elapsedTime >= vestingPeriod
                    ? vs.total
                    : (vs.total * elapsedTime) / vestingPeriod;
                uint256 transferAmount = vested - vs.released;
                address token = vs.token;
                // overflow should be impossible
                released[token] += transferAmount;
                // don't need to worry about re-entrancy; beneficiary cannot pull out more funds than exist in the contract
                // pernicious ERC20s would only mess their own storage, not brick the balance of any ERC20 or ether
                if (token != address(0)) {
                    ERC20(token).safeTransfer(beneficiary, transferAmount);
                } else {
                    beneficiary.safeTransferETH(transferAmount);
                }

                emit ReleaseFromVestingStream(id, transferAmount);
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// functions - views
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - private & internal
    /// -----------------------------------------------------------------------
}
