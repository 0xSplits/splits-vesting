// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {stdError, stdStorage, stdCheats} from "forge-std/stdlib.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {VestingModule} from "../VestingModule.sol";
import {VestingModuleFactory} from "../VestingModuleFactory.sol";
import {MockBeneficiary} from "./mocks/MockBeneficiary.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

// TODO: add erc20 testing
// TODO: add multi stream testing

contract VestingModuleTest is DSTest {
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
        // mint mock tokens to self
        mERC20.mint(type(uint256).max);
    }

    function testCan_receiveETH(uint96 deposit) public {
        successfulDeposit(deposit);
        assertEq(address(vm).balance, deposit);
    }

    function testCan_emitOnReceiveETH(uint96 deposit) public {
        VM.expectEmit(false, false, false, true);
        emit ReceiveETH(deposit);

        successfulDeposit(deposit);
    }

    function testCan_createVestingStreams(uint96 deposit) public {
        successfulDeposit(deposit);

        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
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

    function testCan_emitOnCreateVestingStreams(uint96 deposit) public {
        successfulDeposit(deposit);

        VM.expectEmit(true, true, false, true);
        emit CreateVestingStream(0, address(0), deposit);

        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
        vm.createVestingStreams(tokens);
    }

    function testCan_releaseFromVesting(uint96 deposit) public {
        successfulDeposit(deposit);

        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
        uint256[] memory ids = vm.createVestingStreams(tokens);
        uint256 id = ids[0];
        uint256 vestingStart = block.timestamp;

        VM.warp(vm.vestingPeriod() / 2);

        assertEq(address(mb).balance, 0);
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

        assertEq(address(mb).balance, deposit / 2);
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

        assertEq(address(mb).balance, deposit / 2);
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

        assertEq(address(mb).balance, deposit);
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

    function testCan_emitOnReleaseFromVesting(uint96 deposit) public {
        successfulDeposit(deposit);

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

    /* /// ----------------------------------------------------------------------- */
    /* /// functions - private & internal */
    /* /// ----------------------------------------------------------------------- */

    function successfulDeposit(uint256 deposit) internal {
        (bool success, ) = address(vm).call{value: deposit}("");
        assertTrue(success);
    }

    /* function depositAndVest(uint256 deposit) internal { */
    /*     deposit(deposit); */
    /*     createVestingStream([address(0)]); */
    /* } */

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
