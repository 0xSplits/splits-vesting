// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {VestingModule} from "../VestingModule.sol";
import {VestingModuleFactory} from "../VestingModuleFactory.sol";
import {MockBeneficiary} from "./mocks/MockBeneficiary.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract VestingModuleTest is Test {
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    VestingModuleFactory exampleVmf;
    VestingModule exampleVm;

    MockBeneficiary mb;
    MockERC20 mERC20;

    event ReceiveETH(uint256 amount);

    event CreateVestingStream(
        uint256 indexed id,
        address indexed token,
        uint256 amount
    );

    event ReleaseFromVestingStream(uint256 indexed id, uint256 amount);

    function setUp() public {
        mb = new MockBeneficiary();
        exampleVmf = new VestingModuleFactory();
        exampleVm = exampleVmf.createVestingModule(address(mb), 365 days);

        mERC20 = new MockERC20("Test Token", "TOK", 18);
        mERC20.mint(type(uint256).max);
    }

    /// -----------------------------------------------------------------------
    /// gas benchmarks
    /// -----------------------------------------------------------------------

    function testGas_createAndReleaseStreams() public {
        address token = address(0);
        address[] memory tokens = new address[](1);
        tokens[0] = token;

        // first stream of a token
        address(exampleVm).safeTransferETH(1 ether);
        uint256[] memory ids = exampleVm.createVestingStreams(tokens);
        vm.warp(exampleVm.vestingPeriod());
        uint256[] memory releasedFunds = exampleVm.releaseFromVesting(ids);

        // 2-nth stream of a token
        address(exampleVm).safeTransferETH(1 ether);
        ids = exampleVm.createVestingStreams(tokens);
        vm.warp(exampleVm.vestingPeriod() * 2);
        releasedFunds = exampleVm.releaseFromVesting(ids);
    }

    /// -----------------------------------------------------------------------
    /// correctness tests
    /// -----------------------------------------------------------------------

    function testCan_receiveETH(uint96 deposit) public {
        address(exampleVm).safeTransferETH(deposit);
        assertEq(address(exampleVm).balance, deposit);
    }

    function testCan_emitOnReceiveETH(uint96 deposit) public {
        vm.expectEmit(true, true, true, true);
        emit ReceiveETH(deposit);

        address(exampleVm).safeTransferETH(deposit);
    }

    function testCan_receiveETHTransfer(uint96 deposit) public {
        payable(address(exampleVm)).transfer(deposit);
        assertEq(address(exampleVm).balance, deposit);
    }

    function testCan_createETHVestingStreams(uint96 deposit) public {
        address(exampleVm).safeTransferETH(deposit);
        testCan_createVestingStream(address(0), deposit);
    }

    function testCan_createERC20VestingStreams(uint256 deposit) public {
        ERC20(mERC20).safeTransfer(address(exampleVm), deposit);
        testCan_createVestingStream(address(mERC20), deposit);
    }

    function testCan_emitOnCreateVestingStreams(
        uint96 depositETH,
        uint256 depositERC20
    ) public {
        address(exampleVm).safeTransferETH(depositETH);
        ERC20(mERC20).safeTransfer(address(exampleVm), depositERC20);

        address[] memory tokens = new address[](2);
        tokens[0] = address(0);
        tokens[1] = address(mERC20);

        vm.expectEmit(true, true, true, true);
        emit CreateVestingStream(0, tokens[0], depositETH);

        vm.expectEmit(true, true, true, true);
        emit CreateVestingStream(1, tokens[1], depositERC20);

        exampleVm.createVestingStreams(tokens);
    }

    function testCan_releaseETHFromVesting(uint96 deposit) public {
        address(exampleVm).safeTransferETH(deposit);
        testCan_releaseFromVesting(address(0), deposit);
    }

    function testCan_releaseERC20FromVesting(uint256 deposit) public {
        ERC20(mERC20).safeTransfer(address(exampleVm), deposit);
        testCan_releaseFromVesting(address(mERC20), deposit);
    }

    function testCan_emitOnReleaseFromVesting(uint96 deposit) public {
        address(exampleVm).safeTransferETH(deposit);

        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
        uint256[] memory ids = exampleVm.createVestingStreams(tokens);
        uint256 id = ids[0];

        vm.warp(exampleVm.vestingPeriod() / 2);
        vm.expectEmit(true, true, true, true);
        emit ReleaseFromVestingStream(id, deposit / 2);

        exampleVm.releaseFromVesting(ids);

        vm.warp(exampleVm.vestingPeriod());
        vm.expectEmit(true, true, true, true);
        emit ReleaseFromVestingStream(id, deposit - deposit / 2);

        exampleVm.releaseFromVesting(ids);

        vm.expectEmit(true, true, true, true);
        emit ReleaseFromVestingStream(id, 0);

        exampleVm.releaseFromVesting(ids);
    }

    function testCannot_releaseFromInvalidVestingStreamId(
        uint96 deposit,
        uint256 streamId
    ) public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = streamId;

        vm.expectRevert(
            abi.encodeWithSelector(
                VestingModule.InvalidVestingStreamId.selector,
                streamId
            )
        );
        exampleVm.releaseFromVesting(ids);

        address(exampleVm).safeTransferETH(deposit);

        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
        exampleVm.createVestingStreams(tokens);

        vm.assume(streamId != 0);
        ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = streamId;

        vm.expectRevert(
            abi.encodeWithSelector(
                VestingModule.InvalidVestingStreamId.selector,
                streamId
            )
        );
        exampleVm.releaseFromVesting(ids);
    }

    function testCan_handleTwoVestingStreamsWithDifferentStarts(
        uint48 deposit1,
        uint48 deposit2
    ) public {
        uint256 deposit = uint256(deposit1) + uint256(deposit2);
        address(exampleVm).safeTransferETH(deposit1);
        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
        uint256[] memory ids = exampleVm.createVestingStreams(tokens);

        assertEq(ids.length, tokens.length);
        assertEq(exampleVm.numVestingStreams(), 1);
        assertEq(ids[0], 0);

        vm.warp(exampleVm.vestingPeriod() / 2);

        address(exampleVm).safeTransferETH(deposit2);
        ids = exampleVm.createVestingStreams(tokens);

        assertEq(ids.length, tokens.length);
        assertEq(exampleVm.numVestingStreams(), 2);
        assertEq(ids[0], 1);

        assertEq(exampleVm.vesting(tokens[0]), deposit);
        assertEq(exampleVm.released(tokens[0]), 0);
        assertEq(
            exampleVm.vestingStream(0),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: 0,
                total: deposit1,
                released: 0
            })
        );
        assertEq(
            exampleVm.vestingStream(1),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: exampleVm.vestingPeriod() / 2,
                total: deposit2,
                released: 0
            })
        );
        assertEq(exampleVm.vested(0), deposit1 / 2);
        assertEq(exampleVm.vested(1), 0);
        assertEq(exampleVm.vestedAndUnreleased(0), deposit1 / 2);
        assertEq(exampleVm.vestedAndUnreleased(1), 0);

        vm.warp(exampleVm.vestingPeriod());

        assertEq(exampleVm.numVestingStreams(), 2);
        assertEq(exampleVm.vesting(tokens[0]), deposit);
        assertEq(exampleVm.released(tokens[0]), 0);
        assertEq(
            exampleVm.vestingStream(0),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: 0,
                total: deposit1,
                released: 0
            })
        );
        assertEq(
            exampleVm.vestingStream(1),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: exampleVm.vestingPeriod() / 2,
                total: deposit2,
                released: 0
            })
        );
        assertEq(exampleVm.vested(0), deposit1);
        assertEq(exampleVm.vested(1), deposit2 / 2);
        assertEq(exampleVm.vestedAndUnreleased(0), deposit1);
        assertEq(exampleVm.vestedAndUnreleased(1), deposit2 / 2);

        vm.warp((exampleVm.vestingPeriod() * 3) / 2);

        assertEq(exampleVm.numVestingStreams(), 2);
        assertEq(exampleVm.vesting(tokens[0]), deposit);
        assertEq(exampleVm.released(tokens[0]), 0);
        assertEq(
            exampleVm.vestingStream(0),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: 0,
                total: deposit1,
                released: 0
            })
        );
        assertEq(
            exampleVm.vestingStream(1),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: exampleVm.vestingPeriod() / 2,
                total: deposit2,
                released: 0
            })
        );
        assertEq(exampleVm.vested(0), deposit1);
        assertEq(exampleVm.vested(1), deposit2);
        assertEq(exampleVm.vestedAndUnreleased(0), deposit1);
        assertEq(exampleVm.vestedAndUnreleased(1), deposit2);

        ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;
        uint256[] memory releasedFunds = exampleVm.releaseFromVesting(ids);
        assertEq(releasedFunds[0], deposit1);
        assertEq(releasedFunds[1], deposit2);

        assertEq(getBalance(address(mb), tokens[0]), deposit);
        assertEq(exampleVm.vesting(tokens[0]), deposit);
        assertEq(exampleVm.released(tokens[0]), deposit);
        assertEq(
            exampleVm.vestingStream(0),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: 0,
                total: deposit1,
                released: deposit1
            })
        );
        assertEq(
            exampleVm.vestingStream(1),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: exampleVm.vestingPeriod() / 2,
                total: deposit2,
                released: deposit2
            })
        );
        assertEq(exampleVm.vested(0), deposit1);
        assertEq(exampleVm.vested(1), deposit2);
        assertEq(exampleVm.vestedAndUnreleased(0), 0);
        assertEq(exampleVm.vestedAndUnreleased(1), 0);

        releasedFunds = exampleVm.releaseFromVesting(ids);
        assertEq(releasedFunds[0], 0);
        assertEq(releasedFunds[1], 0);

        assertEq(getBalance(address(mb), tokens[0]), deposit);
        assertEq(exampleVm.vesting(tokens[0]), deposit);
        assertEq(exampleVm.released(tokens[0]), deposit);
        assertEq(
            exampleVm.vestingStream(0),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: 0,
                total: deposit1,
                released: deposit1
            })
        );
        assertEq(
            exampleVm.vestingStream(1),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: exampleVm.vestingPeriod() / 2,
                total: deposit2,
                released: deposit2
            })
        );
        assertEq(exampleVm.vested(0), deposit1);
        assertEq(exampleVm.vested(1), deposit2);
        assertEq(exampleVm.vestedAndUnreleased(0), 0);
        assertEq(exampleVm.vestedAndUnreleased(1), 0);
    }

    function testCan_handleTwoVestingStreamsWithDifferentTokens(
        uint96 deposit1,
        uint256 deposit2
    ) public {
        address(exampleVm).safeTransferETH(deposit1);
        ERC20(mERC20).safeTransfer(address(exampleVm), deposit2);

        address[] memory tokens = new address[](2);
        tokens[0] = address(0);
        tokens[1] = address(mERC20);
        uint256[] memory ids = exampleVm.createVestingStreams(tokens);

        assertEq(ids.length, tokens.length);
        assertEq(exampleVm.numVestingStreams(), 2);
        assertEq(ids[0], 0);
        assertEq(ids[1], 1);

        vm.warp(exampleVm.vestingPeriod() / 2);

        assertEq(exampleVm.vesting(tokens[0]), deposit1);
        assertEq(exampleVm.vesting(tokens[1]), deposit2);
        assertEq(exampleVm.released(tokens[0]), 0);
        assertEq(exampleVm.released(tokens[1]), 0);
        assertEq(
            exampleVm.vestingStream(0),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: 0,
                total: deposit1,
                released: 0
            })
        );
        assertEq(
            exampleVm.vestingStream(1),
            VestingModule.VestingStream({
                token: tokens[1],
                vestingStart: 0,
                total: deposit2,
                released: 0
            })
        );
        assertEq(exampleVm.vested(0), deposit1 / 2);
        assertEq(exampleVm.vested(1), deposit2 / 2);
        assertEq(exampleVm.vestedAndUnreleased(0), deposit1 / 2);
        assertEq(exampleVm.vestedAndUnreleased(1), deposit2 / 2);

        vm.warp(exampleVm.vestingPeriod());

        assertEq(exampleVm.vesting(tokens[0]), deposit1);
        assertEq(exampleVm.vesting(tokens[1]), deposit2);
        assertEq(exampleVm.released(tokens[0]), 0);
        assertEq(exampleVm.released(tokens[1]), 0);
        assertEq(
            exampleVm.vestingStream(0),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: 0,
                total: deposit1,
                released: 0
            })
        );
        assertEq(
            exampleVm.vestingStream(1),
            VestingModule.VestingStream({
                token: tokens[1],
                vestingStart: 0,
                total: deposit2,
                released: 0
            })
        );
        assertEq(exampleVm.vested(0), deposit1);
        assertEq(exampleVm.vested(1), deposit2);
        assertEq(exampleVm.vestedAndUnreleased(0), deposit1);
        assertEq(exampleVm.vestedAndUnreleased(1), deposit2);

        uint256[] memory releasedFunds = exampleVm.releaseFromVesting(ids);
        assertEq(releasedFunds[0], deposit1);
        assertEq(releasedFunds[1], deposit2);

        assertEq(getBalance(address(mb), tokens[0]), deposit1);
        assertEq(getBalance(address(mb), tokens[1]), deposit2);
        assertEq(exampleVm.vesting(tokens[0]), deposit1);
        assertEq(exampleVm.vesting(tokens[1]), deposit2);
        assertEq(exampleVm.released(tokens[0]), deposit1);
        assertEq(exampleVm.released(tokens[1]), deposit2);
        assertEq(
            exampleVm.vestingStream(0),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: 0,
                total: deposit1,
                released: deposit1
            })
        );
        assertEq(
            exampleVm.vestingStream(1),
            VestingModule.VestingStream({
                token: tokens[1],
                vestingStart: 0,
                total: deposit2,
                released: deposit2
            })
        );
        assertEq(exampleVm.vested(0), deposit1);
        assertEq(exampleVm.vested(1), deposit2);
        assertEq(exampleVm.vestedAndUnreleased(0), 0);
        assertEq(exampleVm.vestedAndUnreleased(1), 0);

        releasedFunds = exampleVm.releaseFromVesting(ids);
        assertEq(releasedFunds[0], 0);
        assertEq(releasedFunds[1], 0);

        assertEq(getBalance(address(mb), tokens[0]), deposit1);
        assertEq(getBalance(address(mb), tokens[1]), deposit2);
        assertEq(exampleVm.vesting(tokens[0]), deposit1);
        assertEq(exampleVm.vesting(tokens[1]), deposit2);
        assertEq(exampleVm.released(tokens[0]), deposit1);
        assertEq(exampleVm.released(tokens[1]), deposit2);
        assertEq(
            exampleVm.vestingStream(0),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: 0,
                total: deposit1,
                released: deposit1
            })
        );
        assertEq(
            exampleVm.vestingStream(1),
            VestingModule.VestingStream({
                token: tokens[1],
                vestingStart: 0,
                total: deposit2,
                released: deposit2
            })
        );
        assertEq(exampleVm.vested(0), deposit1);
        assertEq(exampleVm.vested(1), deposit2);
        assertEq(exampleVm.vestedAndUnreleased(0), 0);
        assertEq(exampleVm.vestedAndUnreleased(1), 0);

        vm.warp(exampleVm.vestingPeriod() * 2);

        releasedFunds = exampleVm.releaseFromVesting(ids);
        assertEq(releasedFunds[0], 0);
        assertEq(releasedFunds[1], 0);

        assertEq(getBalance(address(mb), tokens[0]), deposit1);
        assertEq(getBalance(address(mb), tokens[1]), deposit2);
        assertEq(exampleVm.vesting(tokens[0]), deposit1);
        assertEq(exampleVm.vesting(tokens[1]), deposit2);
        assertEq(exampleVm.released(tokens[0]), deposit1);
        assertEq(exampleVm.released(tokens[1]), deposit2);
        assertEq(
            exampleVm.vestingStream(0),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: 0,
                total: deposit1,
                released: deposit1
            })
        );
        assertEq(
            exampleVm.vestingStream(1),
            VestingModule.VestingStream({
                token: tokens[1],
                vestingStart: 0,
                total: deposit2,
                released: deposit2
            })
        );
        assertEq(exampleVm.vested(0), deposit1);
        assertEq(exampleVm.vested(1), deposit2);
        assertEq(exampleVm.vestedAndUnreleased(0), 0);
        assertEq(exampleVm.vestedAndUnreleased(1), 0);
    }

    /* /// ----------------------------------------------------------------------- */
    /* /// functions - private & internal */
    /* /// ----------------------------------------------------------------------- */

    function testCan_createVestingStream(address token, uint256 deposit)
        internal
    {
        vm.assume(deposit != 0);
        uint256 fnStart = block.timestamp;

        address[] memory tokens = new address[](1);
        tokens[0] = token;
        uint256[] memory ids = exampleVm.createVestingStreams(tokens);

        assertEq(ids.length, tokens.length);
        assertEq(exampleVm.numVestingStreams(), 1);
        uint256 id = ids[0];

        assertEq(id, 0);
        assertEq(exampleVm.vesting(tokens[0]), deposit);
        assertEq(exampleVm.released(tokens[0]), 0);
        assertEq(
            exampleVm.vestingStream(id),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: fnStart,
                total: deposit,
                released: 0
            })
        );
        assertEq(exampleVm.vested(id), 0);

        vm.warp(fnStart + exampleVm.vestingPeriod() / 2);
        assertEq(exampleVm.vesting(tokens[0]), deposit);
        assertEq(exampleVm.released(tokens[0]), 0);
        assertEq(
            exampleVm.vestingStream(id),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: fnStart,
                total: deposit,
                released: 0
            })
        );
        assertEq(exampleVm.vested(id), deposit / 2);

        vm.warp(fnStart + exampleVm.vestingPeriod());
        assertEq(exampleVm.vesting(tokens[0]), deposit);
        assertEq(exampleVm.released(tokens[0]), 0);
        assertEq(
            exampleVm.vestingStream(id),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: fnStart,
                total: deposit,
                released: 0
            })
        );
        assertEq(exampleVm.vested(id), deposit);

        // make sure fn leaves timestamp unchanged
        vm.warp(fnStart);
    }

    function testCan_releaseFromVesting(address token, uint256 deposit)
        internal
    {
        uint256 fnStart = block.timestamp;

        address[] memory tokens = new address[](1);
        tokens[0] = token;
        uint256[] memory ids = exampleVm.createVestingStreams(tokens);
        uint256 id = ids[0];

        vm.warp(fnStart + exampleVm.vestingPeriod() / 2);

        assertEq(getBalance(address(mb), token), 0);
        assertEq(exampleVm.vesting(tokens[0]), deposit);
        assertEq(exampleVm.released(tokens[0]), 0);
        assertEq(
            exampleVm.vestingStream(id),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: fnStart,
                total: deposit,
                released: 0
            })
        );
        assertEq(exampleVm.vested(id), deposit / 2);
        assertEq(exampleVm.vestedAndUnreleased(id), deposit / 2);

        uint256[] memory releasedFunds = exampleVm.releaseFromVesting(ids);
        assertEq(releasedFunds[0], deposit / 2);

        assertEq(getBalance(address(mb), token), deposit / 2);
        assertEq(exampleVm.vesting(tokens[0]), deposit);
        assertEq(exampleVm.released(tokens[0]), deposit / 2);
        assertEq(
            exampleVm.vestingStream(id),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: fnStart,
                total: deposit,
                released: deposit / 2
            })
        );
        assertEq(exampleVm.vested(id), deposit / 2);
        assertEq(exampleVm.vestedAndUnreleased(id), 0);

        vm.warp(fnStart + exampleVm.vestingPeriod());

        assertEq(getBalance(address(mb), token), deposit / 2);
        assertEq(exampleVm.vesting(tokens[0]), deposit);
        assertEq(exampleVm.released(tokens[0]), deposit / 2);
        assertEq(
            exampleVm.vestingStream(id),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: fnStart,
                total: deposit,
                released: deposit / 2
            })
        );
        assertEq(exampleVm.vested(id), deposit);
        assertEq(exampleVm.vestedAndUnreleased(id), deposit - deposit / 2);

        releasedFunds = exampleVm.releaseFromVesting(ids);
        assertEq(releasedFunds[0], deposit - deposit / 2);

        assertEq(getBalance(address(mb), token), deposit);
        assertEq(exampleVm.vesting(tokens[0]), deposit);
        assertEq(exampleVm.released(tokens[0]), deposit);
        assertEq(
            exampleVm.vestingStream(id),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: fnStart,
                total: deposit,
                released: deposit
            })
        );
        assertEq(exampleVm.vested(id), deposit);
        assertEq(exampleVm.vestedAndUnreleased(id), 0);

        releasedFunds = exampleVm.releaseFromVesting(ids);
        assertEq(releasedFunds[0], 0);

        assertEq(getBalance(address(mb), token), deposit);
        assertEq(exampleVm.vesting(tokens[0]), deposit);
        assertEq(exampleVm.released(tokens[0]), deposit);
        assertEq(
            exampleVm.vestingStream(id),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: fnStart,
                total: deposit,
                released: deposit
            })
        );
        assertEq(exampleVm.vested(id), deposit);
        assertEq(exampleVm.vestedAndUnreleased(id), 0);

        vm.warp(fnStart + exampleVm.vestingPeriod() * 2);
        releasedFunds = exampleVm.releaseFromVesting(ids);
        assertEq(releasedFunds[0], 0);

        assertEq(getBalance(address(mb), token), deposit);
        assertEq(exampleVm.vesting(tokens[0]), deposit);
        assertEq(exampleVm.released(tokens[0]), deposit);
        assertEq(
            exampleVm.vestingStream(id),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: fnStart,
                total: deposit,
                released: deposit
            })
        );
        assertEq(exampleVm.vested(id), deposit);
        assertEq(exampleVm.vestedAndUnreleased(id), 0);

        // make sure fn leaves timestamp unchanged
        vm.warp(fnStart);
    }

    function getBalance(address target, address token)
        internal
        view
        returns (uint256)
    {
        return (
            token != address(0)
                ? ERC20(token).balanceOf(target)
                : address(target).balance
        );
    }

    function assertEq(
        VestingModule.VestingStream memory actualVs,
        VestingModule.VestingStream memory expectedVs
    ) internal {
        assertEq(actualVs.token, expectedVs.token);
        assertEq(actualVs.vestingStart, expectedVs.vestingStart);
        assertEq(actualVs.total, expectedVs.total);
        assertEq(actualVs.released, expectedVs.released);
    }
}
