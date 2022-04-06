// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

/* import {DSTest} from "ds-test/test.sol"; */
import "ds-test/test.sol";
import {stdError, stdStorage, stdCheats} from "forge-std/stdlib.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {VestingModule} from "../VestingModule.sol";
import {MockBeneficiary} from "./mocks/MockBeneficiary.sol";

contract VestingModuleTest is DSTest {
    Vm public constant VM = Vm(HEVM_ADDRESS);

    VestingModule vm;
    MockBeneficiary mb;

    event CreateVestingModule(
        address indexed beneficiary,
        uint256 vestingPeriod
    );

    function setUp() public {
        mb = new MockBeneficiary();
        vm = new VestingModule(address(mb), 0);
        /* exampleToken = new MockERC20("Test Token", "TOK", 18); */
    }

    function testCan_createVestingModule(
        address beneficiary,
        uint256 vestingPeriod
    ) public {
        VM.assume(beneficiary != address(0));
        vestingPeriod = vestingPeriod != 0 ? vestingPeriod : 365 days;

        VM.expectEmit(true, false, false, true);
        emit CreateVestingModule(beneficiary, vestingPeriod);

        vm = new VestingModule(beneficiary, vestingPeriod);
        assertEq(beneficiary, vm.beneficiary());
        assertEq(vm.vestingPeriod(), vestingPeriod);
    }

    function testCannot_setBeneficiaryToAddressZero(uint256 vestingPeriod)
        public
    {
        VM.expectRevert(VestingModule.InvalidBeneficiary.selector);

        vm = new VestingModule(address(0), vestingPeriod);
    }

    function testCan_receiveDeposit(uint96 deposit) public {
        (bool success, ) = address(vm).call{value: deposit}("");
        assertTrue(success);
        assertEq(address(vm).balance, deposit);
    }

    function testCan_addToVest(uint96 deposit) public {
        vestDeposit(deposit);

        assertEq(vm.vestingStart(), block.timestamp);
        assertEq(vm.vesting(), deposit);
        assertEq(vm.vestingClaimed(), 0);
        assertEq(vm.toBeClaimed(), 0);
        assertEq(vm.vestedAndUnclaimed(), 0);

        VM.warp(vm.vestingPeriod() / 2);
        assertEq(vm.vestedAndUnclaimed(), deposit / 2);

        VM.warp(vm.vestingPeriod());
        assertEq(vm.vestedAndUnclaimed(), deposit);
    }

    function testCan_claimFromVest(uint96 deposit) public {
        vestDeposit(deposit);
        VM.warp(vm.vestingPeriod());
        vm.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(vm.vesting(), deposit);
        assertEq(vm.vestingClaimed(), deposit);
        assertEq(vm.toBeClaimed(), 0);
        assertEq(vm.vestedAndUnclaimed(), 0);
    }

    function testCan_dep_dep_add(
        uint8 depositGap,
        uint48 deposit1,
        uint48 deposit2
    ) public {
        uint256 deposit = uint256(deposit1) + uint256(deposit2);
        successfulDeposit(deposit1);
        VM.warp(depositGap);
        successfulDeposit(deposit2);
        vm.addToVest();

        assertEq(vm.vestingStart(), depositGap);
        assertEq(vm.vesting(), deposit);
        assertEq(vm.vestingClaimed(), 0);
        assertEq(vm.toBeClaimed(), 0);
        assertEq(vm.vestedAndUnclaimed(), 0);
    }

    function testCan_dep_add_dep_add(
        uint8 depositGap,
        uint48 deposit1,
        uint48 deposit2
    ) public {
        uint256 deposit = uint256(deposit1) + uint256(deposit2);
        vestDeposit(deposit1);
        VM.warp(depositGap);
        vestDeposit(deposit2);
        VM.warp(vm.vestingPeriod() + depositGap);

        assertEq(vm.vestingStart(), depositGap);
        assertEq(
            vm.vesting(),
            uint256(deposit2) +
                deposit1 -
                (uint256(deposit1) * depositGap) /
                vm.vestingPeriod()
        );
        assertEq(vm.vestingClaimed(), 0);
        assertEq(
            vm.toBeClaimed(),
            (uint256(deposit1) * depositGap) / vm.vestingPeriod()
        );
        assertEq(vm.vestedAndUnclaimed(), deposit);
    }

    function testCan_add_add_claim(uint48 deposit1, uint48 deposit2) public {
        uint256 deposit = uint256(deposit1) + uint256(deposit2);
        vestDeposit(deposit1);
        VM.warp(vm.vestingPeriod() / 2);
        vestDeposit(deposit2);
        VM.warp((vm.vestingPeriod() * 3) / 2);
        vm.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(vm.vesting(), uint256(deposit1) - deposit1 / 2 + deposit2);
        assertEq(
            vm.vestingClaimed(),
            uint256(deposit1) - deposit1 / 2 + deposit2
        );
        assertEq(vm.toBeClaimed(), 0);
        assertEq(vm.vestedAndUnclaimed(), 0);
    }

    function testCan_add_claim_add_claim(uint48 deposit1, uint48 deposit2)
        public
    {
        uint256 deposit = uint256(deposit1) + uint256(deposit2);
        vestDeposit(deposit1);
        VM.warp(vm.vestingPeriod() / 2);
        vm.claimFromVest();
        vestDeposit(deposit2);
        VM.warp((vm.vestingPeriod() * 3) / 2);
        vm.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(vm.vesting(), uint256(deposit1) - deposit1 / 2 + deposit2);
        assertEq(
            vm.vestingClaimed(),
            uint256(deposit1) - deposit1 / 2 + deposit2
        );
        assertEq(vm.toBeClaimed(), 0);
        assertEq(vm.vestedAndUnclaimed(), 0);
    }

    function testCan_add_claim_add_claim_add_claim(
        uint48 deposit1,
        uint48 deposit2,
        uint48 deposit3
    ) public {
        uint256 deposit = uint256(deposit1) +
            uint256(deposit2) +
            uint256(deposit3);
        vestDeposit(deposit1);
        VM.warp(vm.vestingPeriod() / 2);
        vm.claimFromVest();
        vestDeposit(deposit2);
        VM.warp(vm.vestingPeriod());
        vm.claimFromVest();
        vestDeposit(deposit3);
        VM.warp(2 * vm.vestingPeriod());
        vm.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(vm.toBeClaimed(), 0);
        assertEq(vm.vestedAndUnclaimed(), 0);
    }

    function testCan_add_claim_claim_claim(uint96 deposit) public {
        vestDeposit(deposit);

        VM.warp(vm.vestingPeriod() / 2);
        vm.claimFromVest();

        assertEq(address(mb).balance, deposit / 2);
        assertEq(vm.vesting(), deposit);
        assertEq(vm.vestingClaimed(), deposit / 2);
        assertEq(vm.toBeClaimed(), 0);
        assertEq(vm.vestedAndUnclaimed(), 0);

        VM.warp(vm.vestingPeriod());

        assertEq(address(mb).balance, deposit / 2);
        assertEq(vm.vesting(), deposit);
        assertEq(vm.vestingClaimed(), deposit / 2);
        assertEq(vm.toBeClaimed(), 0);
        assertEq(vm.vestedAndUnclaimed(), deposit - deposit / 2);

        vm.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(vm.vesting(), deposit);
        assertEq(vm.vestingClaimed(), deposit);
        assertEq(vm.toBeClaimed(), 0);
        assertEq(vm.vestedAndUnclaimed(), 0);

        VM.warp(vm.vestingPeriod() + 1);
        vm.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(vm.vesting(), deposit);
        assertEq(vm.vestingClaimed(), deposit);
        assertEq(vm.toBeClaimed(), 0);
        assertEq(vm.vestedAndUnclaimed(), 0);
    }

    /// -----------------------------------------------------------------------
    /// functions - private & internal
    /// -----------------------------------------------------------------------

    function successfulDeposit(uint256 deposit) internal {
        (bool success, ) = address(vm).call{value: deposit}("");
        assertTrue(success);
    }

    function vestDeposit(uint256 deposit) internal {
        successfulDeposit(deposit);
        vm.addToVest();
    }
}
