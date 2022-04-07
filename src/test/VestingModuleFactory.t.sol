// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

/* import {DSTest} from "ds-test/test.sol"; */
import "ds-test/test.sol";
import {stdError, stdStorage, stdCheats} from "forge-std/stdlib.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {VestingModule} from "../VestingModule.sol";
import {VestingModuleFactory} from "../VestingModuleFactory.sol";
import {MockBeneficiary} from "./mocks/MockBeneficiary.sol";

contract VestingModuleTest is DSTest {
    Vm public constant VM = Vm(HEVM_ADDRESS);

    VestingModule vm_impl;
    VestingModuleFactory vmf;
    VestingModule vm_clone;

    MockBeneficiary mb;

    event CreateVestingModule(
        address indexed beneficiary,
        uint256 vestingPeriod
    );

    function setUp() public {
        mb = new MockBeneficiary();
        vm_impl = new VestingModule();
        vmf = new VestingModuleFactory(vm);
    }

    function testCan_createVestingModule(
        address beneficiary,
        uint256 vestingPeriod
    ) public {
        VM.assume(beneficiary != address(0));
        VM.assume(vestingPeriod != 0);

        VM.expectEmit(true, false, false, true);
        emit CreateVestingModule(beneficiary, vestingPeriod);

        vm_clone = vmf.createVestingModuleClone(beneficiary, vestingPeriod);

        assertEq(vm_clone.beneficiary(), beneficiary);
        assertEq(vm_clone.vestingPeriod(), vestingPeriod);
    }
}
