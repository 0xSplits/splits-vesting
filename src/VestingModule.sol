// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import {Clone} from "clones-with-immutable-args/Clone.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FullMath} from "./lib/FullMath.sol";

// TODO: header
/// @dev this contract uses address(0) in some events/mappings to refer to ETH

contract VestingModule is Clone {
    /// -----------------------------------------------------------------------
    /// errors
    /// -----------------------------------------------------------------------

    error InvalidVestingStreamId(uint256 id);

    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------

    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    /// -----------------------------------------------------------------------
    /// events
    /// -----------------------------------------------------------------------

    /// @notice New vesting stream created
    /// @param id Id of vesting stream
    /// @param token Address of token to vest (0x0 for ETH)
    /// @param amount Amount to vest
    event CreateVestingStream(
        uint256 indexed id,
        address indexed token,
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
    /// storage
    /// -----------------------------------------------------------------------

    /// Address to receive funds after vesting
    /// @dev address public immutable beneficiary;
    function beneficiary() public pure returns (address) {
        return _getArgAddress(0);
    }

    /// Period of time for funds to vest (defaults to 365 days)
    /// @dev uint256 public immutable vestingPeriod;
    function vestingPeriod() public pure returns (uint256) {
        return _getArgUint256(20);
    }

    /// Number of vesting streams
    /// @dev Used for sequential ids
    uint256 public numVestingStreams;

    // TODO: verify this accessor is sufficient
    /// Mapping from Id to vesting stream
    mapping(uint256 => VestingStream) internal vestingStreams;
    /// Mapping from token to amount vesting (includes current & previous)
    mapping(address => uint256) public vesting;
    /// Mapping from token to amount released
    mapping(address => uint256) public released;

    /// -----------------------------------------------------------------------
    /// constructor
    /// -----------------------------------------------------------------------

    constructor() {}

    /// -----------------------------------------------------------------------
    /// functions
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - public & external
    /// -----------------------------------------------------------------------

    /// @notice receive ETH
    /// @dev can't use receive with clones-with-immutable-args because it
    /// expects empty calldata while the clone always appends the immutables
    fallback() external payable {
        emit ReceiveETH(msg.value);
    }

    // TODO: worthwhile to return created ids?
    /// @notice Creates new vesting streams
    /// @notice tokens Addresses of ETH (0x0) & ERC20s to create vesting streams for
    function createVestingStreams(address[] calldata tokens)
        external
        payable
        returns (uint256[] memory ids)
    {
        uint256 numTokens = tokens.length;
        ids = new uint256[](numTokens);
        // use count as first new sequential id
        uint256 vestingStreamId = numVestingStreams;

        unchecked {
            // overflow should be impossible in for-loop index
            for (uint256 i = 0; i < numTokens; ++i) {
                address token = tokens[i];
                // overflow should be impossible
                // shouldn't need to worry about re-entrancy from ERC20 view fn
                // recognizes 0x0 as ETH
                uint256 pendingAmount = (
                    token != address(0)
                        ? ERC20(token).balanceOf(address(this))
                        : address(this).balance
                ) +
                    released[token] -
                    vesting[token];
                vesting[token] += pendingAmount;
                // overflow should be impossible
                vestingStreams[vestingStreamId] = VestingStream({
                    token: token,
                    vestingStart: block.timestamp,
                    total: pendingAmount,
                    released: 0
                });
                emit CreateVestingStream(vestingStreamId, token, pendingAmount);
                ids[i] = vestingStreamId;
                ++vestingStreamId;
            }
            // use last created id as new count
            numVestingStreams = vestingStreamId;
        }
    }

    // TODO: anything we should return from this? amounts released?
    /// @notice Releases vested funds to the beneficiary
    /// @notice ids Ids of vesting streams to release funds from
    function releaseFromVesting(uint256[] calldata ids) external payable {
        unchecked {
            uint256 numIds = ids.length;
            // overflow should be impossible in for-loop index
            for (uint256 i = 0; i < numIds; ++i) {
                uint256 id = ids[i];
                if (id >= numVestingStreams) revert InvalidVestingStreamId(id);
                VestingStream memory vs = vestingStreams[id];
                uint256 transferAmount = vestedAndUnreleased(vs);
                address token = vs.token;
                // overflow should be impossible
                vestingStreams[id].released += transferAmount;
                // overflow should be impossible
                released[token] += transferAmount;
                // don't need to worry about re-entrancy; funds can't be stolen from beneficiary
                // pernicious ERC20s would only mess their own storage, not brick the balance of any ERC20 or ETH
                if (token != address(0)) {
                    ERC20(token).safeTransfer(beneficiary(), transferAmount);
                } else {
                    beneficiary().safeTransferETH(transferAmount);
                }

                emit ReleaseFromVestingStream(id, transferAmount);
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// functions - views
    /// -----------------------------------------------------------------------

    function vestingStream(uint256 id)
        external
        view
        returns (VestingStream memory vs)
    {
        vs = vestingStreams[id];
    }

    function vested(uint256 id) public view returns (uint256) {
        VestingStream memory vs = vestingStreams[id];
        return vested(vs);
    }

    function vestedAndUnreleased(uint256 id) public view returns (uint256) {
        VestingStream memory vs = vestingStreams[id];
        return vestedAndUnreleased(vs);
    }

    /// -----------------------------------------------------------------------
    /// functions - private & internal
    /// -----------------------------------------------------------------------

    function vested(VestingStream memory vs) internal view returns (uint256) {
        uint256 elapsedTime;
        unchecked {
            // underflow should be impossible
            elapsedTime = block.timestamp - vs.vestingStart;
        }
        return
            elapsedTime >= vestingPeriod()
                ? vs.total
                : FullMath.mulDiv(vs.total, elapsedTime, vestingPeriod());
    }

    function vestedAndUnreleased(VestingStream memory vs)
        internal
        view
        returns (uint256)
    {
        unchecked {
            // underflow should be impossible
            return vested(vs) - vs.released;
        }
    }
}
