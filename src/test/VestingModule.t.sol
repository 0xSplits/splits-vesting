// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {stdError, stdStorage, stdCheats} from "forge-std/stdlib.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {VestingModule} from "../VestingModule.sol";
import {VestingModuleFactory} from "../VestingModuleFactory.sol";
import {MockBeneficiary} from "./mocks/MockBeneficiary.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract VestingModuleTest is DSTest {
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    Vm public constant VM = Vm(HEVM_ADDRESS);

    VestingModuleFactory vmf;
    VestingModule vm;

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
        vmf = new VestingModuleFactory(new VestingModule());
        vm = vmf.createVestingModule(address(mb), 365 days);

        mERC20 = new MockERC20("Test Token", "TOK", 18);
        mERC20.mint(type(uint256).max);
    }

    function testCan_receiveETH(uint96 deposit) public {
        address(vm).safeTransferETH(deposit);
        assertEq(address(vm).balance, deposit);
    }

    function testCan_emitOnReceiveETH(uint96 deposit) public {
        VM.expectEmit(false, false, false, true);
        emit ReceiveETH(deposit);

        address(vm).safeTransferETH(deposit);
    }

    function testCan_createETHVestingStreams(uint96 deposit) public {
        address(vm).safeTransferETH(deposit);
        testCan_createVestingStream(address(0), deposit);
    }

    function testCan_createERC20VestingStreams(uint256 deposit) public {
        ERC20(mERC20).safeTransfer(address(vm), deposit);
        testCan_createVestingStream(address(mERC20), deposit);
    }

    function testCan_emitOnCreateVestingStreams(
        uint96 depositETH,
        uint256 depositERC20
    ) public {
        address(vm).safeTransferETH(depositETH);
        ERC20(mERC20).safeTransfer(address(vm), depositERC20);

        address[] memory tokens = new address[](2);
        tokens[0] = address(0);
        tokens[1] = address(mERC20);

        VM.expectEmit(true, true, false, true);
        emit CreateVestingStream(0, tokens[0], depositETH);

        VM.expectEmit(true, true, false, true);
        emit CreateVestingStream(1, tokens[1], depositERC20);

        vm.createVestingStreams(tokens);
    }

    function testCan_releaseETHFromVesting(uint96 deposit) public {
        address(vm).safeTransferETH(deposit);
        testCan_releaseFromVesting(address(0), deposit);
    }

    function testCan_releaseERC20FromVesting(uint256 deposit) public {
        ERC20(mERC20).safeTransfer(address(vm), deposit);
        testCan_releaseFromVesting(address(mERC20), deposit);
    }

    function testCan_emitOnReleaseFromVesting(uint96 deposit) public {
        address(vm).safeTransferETH(deposit);

        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
        uint256[] memory ids = vm.createVestingStreams(tokens);
        uint256 id = ids[0];

        VM.warp(vm.vestingPeriod() / 2);
        VM.expectEmit(true, false, false, true);
        emit ReleaseFromVestingStream(id, deposit / 2);

        vm.releaseFromVesting(ids);

        VM.warp(vm.vestingPeriod());
        VM.expectEmit(true, false, false, true);
        emit ReleaseFromVestingStream(id, deposit - deposit / 2);

        vm.releaseFromVesting(ids);
    }

    function testCannot_releaseFromInvalidVestingStreamId(
        uint96 deposit,
        uint256 streamId
    ) public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = streamId;

        VM.expectRevert(
            abi.encodeWithSelector(
                VestingModule.InvalidVestingStreamId.selector,
                streamId
            )
        );
        vm.releaseFromVesting(ids);

        address(vm).safeTransferETH(deposit);

        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
        vm.createVestingStreams(tokens);

        VM.assume(streamId != 0);
        ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = streamId;

        VM.expectRevert(
            abi.encodeWithSelector(
                VestingModule.InvalidVestingStreamId.selector,
                streamId
            )
        );
        vm.releaseFromVesting(ids);
    }

    function testCan_handleTwoVestingStreamsWithDifferentStarts(
        uint48 deposit1,
        uint48 deposit2
    ) public {
        uint256 deposit = uint256(deposit1) + uint256(deposit2);
        address(vm).safeTransferETH(deposit1);
        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
        uint256[] memory ids = vm.createVestingStreams(tokens);

        assertEq(ids.length, tokens.length);
        assertEq(vm.numVestingStreams(), 1);
        assertEq(ids[0], 0);

        VM.warp(vm.vestingPeriod() / 2);

        address(vm).safeTransferETH(deposit2);
        ids = vm.createVestingStreams(tokens);

        assertEq(ids.length, tokens.length);
        assertEq(vm.numVestingStreams(), 2);
        assertEq(ids[0], 1);

        assertEq(vm.vesting(tokens[0]), deposit);
        assertEq(vm.released(tokens[0]), 0);
        assertEq(
            vm.vestingStream(0),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: 0,
                total: deposit1,
                released: 0
            })
        );
        assertEq(
            vm.vestingStream(1),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: vm.vestingPeriod() / 2,
                total: deposit2,
                released: 0
            })
        );
        assertEq(vm.vested(0), deposit1 / 2);
        assertEq(vm.vested(1), 0);

        VM.warp(vm.vestingPeriod());

        assertEq(vm.numVestingStreams(), 2);
        assertEq(vm.vesting(tokens[0]), deposit);
        assertEq(vm.released(tokens[0]), 0);
        assertEq(
            vm.vestingStream(0),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: 0,
                total: deposit1,
                released: 0
            })
        );
        assertEq(
            vm.vestingStream(1),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: vm.vestingPeriod() / 2,
                total: deposit2,
                released: 0
            })
        );
        assertEq(vm.vested(0), deposit1);
        assertEq(vm.vested(1), deposit2 / 2);

        VM.warp((vm.vestingPeriod() * 3) / 2);

        assertEq(vm.numVestingStreams(), 2);
        assertEq(vm.vesting(tokens[0]), deposit);
        assertEq(vm.released(tokens[0]), 0);
        assertEq(
            vm.vestingStream(0),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: 0,
                total: deposit1,
                released: 0
            })
        );
        assertEq(
            vm.vestingStream(1),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: vm.vestingPeriod() / 2,
                total: deposit2,
                released: 0
            })
        );
        assertEq(vm.vested(0), deposit1);
        assertEq(vm.vested(1), deposit2);

        ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;
        vm.releaseFromVesting(ids);

        assertEq(getBalance(address(mb), tokens[0]), deposit);
        assertEq(vm.vesting(tokens[0]), deposit);
        assertEq(vm.released(tokens[0]), deposit);
        assertEq(
            vm.vestingStream(0),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: 0,
                total: deposit1,
                released: deposit1
            })
        );
        assertEq(
            vm.vestingStream(1),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: vm.vestingPeriod() / 2,
                total: deposit2,
                released: deposit2
            })
        );
        assertEq(vm.vested(0), deposit1);
        assertEq(vm.vested(1), deposit2);
    }

    function testCan_handleTwoVestingStreamsWithDifferentTokens(
        uint96 deposit1,
        uint256 deposit2
    ) public {
        address(vm).safeTransferETH(deposit1);
        ERC20(mERC20).safeTransfer(address(vm), deposit2);

        address[] memory tokens = new address[](2);
        tokens[0] = address(0);
        tokens[1] = address(mERC20);
        uint256[] memory ids = vm.createVestingStreams(tokens);

        assertEq(ids.length, tokens.length);
        assertEq(vm.numVestingStreams(), 2);
        assertEq(ids[0], 0);
        assertEq(ids[1], 1);

        VM.warp(vm.vestingPeriod() / 2);

        assertEq(vm.vesting(tokens[0]), deposit1);
        assertEq(vm.vesting(tokens[1]), deposit2);
        assertEq(vm.released(tokens[0]), 0);
        assertEq(vm.released(tokens[1]), 0);
        assertEq(
            vm.vestingStream(0),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: 0,
                total: deposit1,
                released: 0
            })
        );
        assertEq(
            vm.vestingStream(1),
            VestingModule.VestingStream({
                token: tokens[1],
                vestingStart: 0,
                total: deposit2,
                released: 0
            })
        );
        assertEq(vm.vested(0), deposit1 / 2);
        assertEq(vm.vested(1), deposit2 / 2);

        VM.warp(vm.vestingPeriod());

        assertEq(vm.vesting(tokens[0]), deposit1);
        assertEq(vm.vesting(tokens[1]), deposit2);
        assertEq(vm.released(tokens[0]), 0);
        assertEq(vm.released(tokens[1]), 0);
        assertEq(
            vm.vestingStream(0),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: 0,
                total: deposit1,
                released: 0
            })
        );
        assertEq(
            vm.vestingStream(1),
            VestingModule.VestingStream({
                token: tokens[1],
                vestingStart: 0,
                total: deposit2,
                released: 0
            })
        );
        assertEq(vm.vested(0), deposit1);
        assertEq(vm.vested(1), deposit2);

        vm.releaseFromVesting(ids);

        assertEq(getBalance(address(mb), tokens[0]), deposit1);
        assertEq(getBalance(address(mb), tokens[1]), deposit2);
        assertEq(vm.vesting(tokens[0]), deposit1);
        assertEq(vm.vesting(tokens[1]), deposit2);
        assertEq(vm.released(tokens[0]), deposit1);
        assertEq(vm.released(tokens[1]), deposit2);
        assertEq(
            vm.vestingStream(0),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: 0,
                total: deposit1,
                released: deposit1
            })
        );
        assertEq(
            vm.vestingStream(1),
            VestingModule.VestingStream({
                token: tokens[1],
                vestingStart: 0,
                total: deposit2,
                released: deposit2
            })
        );
        assertEq(vm.vested(0), deposit1);
        assertEq(vm.vested(1), deposit2);
    }

    function testCan_handleMultipleVestingStreams(uint256 deposit) public {
        ERC20(mERC20).safeTransfer(address(vm), deposit);
        testCan_createVestingStream(address(mERC20), deposit);
    }

    /* /// ----------------------------------------------------------------------- */
    /* /// functions - private & internal */
    /* /// ----------------------------------------------------------------------- */

    function testCan_createVestingStream(address token, uint256 deposit)
        internal
    {
        VM.assume(deposit != 0);

        address[] memory tokens = new address[](1);
        tokens[0] = token;
        uint256[] memory ids = vm.createVestingStreams(tokens);
        uint256 vestingStart = block.timestamp;

        assertEq(ids.length, tokens.length);
        assertEq(vm.numVestingStreams(), 1);
        uint256 id = ids[0];

        assertEq(id, 0);
        assertEq(vm.vesting(tokens[0]), deposit);
        assertEq(vm.released(tokens[0]), 0);
        assertEq(
            vm.vestingStream(id),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: vestingStart,
                total: deposit,
                released: 0
            })
        );
        assertEq(vm.vested(id), 0);

        VM.warp(vm.vestingPeriod() / 2);
        assertEq(vm.vesting(tokens[0]), deposit);
        assertEq(vm.released(tokens[0]), 0);
        assertEq(
            vm.vestingStream(id),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: vestingStart,
                total: deposit,
                released: 0
            })
        );
        assertEq(vm.vested(id), deposit / 2);

        VM.warp(vm.vestingPeriod());
        assertEq(vm.vesting(tokens[0]), deposit);
        assertEq(vm.released(tokens[0]), 0);
        assertEq(
            vm.vestingStream(id),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: vestingStart,
                total: deposit,
                released: 0
            })
        );
        assertEq(vm.vested(id), deposit);
    }

    function testCan_releaseFromVesting(address token, uint256 deposit)
        internal
    {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        uint256[] memory ids = vm.createVestingStreams(tokens);
        uint256 id = ids[0];
        uint256 vestingStart = block.timestamp;

        VM.warp(vm.vestingPeriod() / 2);

        assertEq(getBalance(address(mb), token), 0);
        assertEq(vm.vesting(tokens[0]), deposit);
        assertEq(vm.released(tokens[0]), 0);
        assertEq(
            vm.vestingStream(id),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: vestingStart,
                total: deposit,
                released: 0
            })
        );
        assertEq(vm.vested(id), deposit / 2);

        vm.releaseFromVesting(ids);

        assertEq(getBalance(address(mb), token), deposit / 2);
        assertEq(vm.vesting(tokens[0]), deposit);
        assertEq(vm.released(tokens[0]), deposit / 2);
        assertEq(
            vm.vestingStream(id),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: vestingStart,
                total: deposit,
                released: deposit / 2
            })
        );
        assertEq(vm.vested(id), deposit / 2);

        VM.warp(vm.vestingPeriod());

        assertEq(getBalance(address(mb), token), deposit / 2);
        assertEq(vm.vesting(tokens[0]), deposit);
        assertEq(vm.released(tokens[0]), deposit / 2);
        assertEq(
            vm.vestingStream(id),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: vestingStart,
                total: deposit,
                released: deposit / 2
            })
        );
        assertEq(vm.vested(id), deposit);

        vm.releaseFromVesting(ids);

        assertEq(getBalance(address(mb), token), deposit);
        assertEq(vm.vesting(tokens[0]), deposit);
        assertEq(vm.released(tokens[0]), deposit);
        assertEq(
            vm.vestingStream(id),
            VestingModule.VestingStream({
                token: tokens[0],
                vestingStart: vestingStart,
                total: deposit,
                released: deposit
            })
        );
        assertEq(vm.vested(id), deposit);
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
