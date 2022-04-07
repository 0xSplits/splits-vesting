// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {stdError, stdStorage, stdCheats} from "forge-std/stdlib.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {VestingModule} from "../VestingModule.sol";
import {VestingModuleFactory} from "../VestingModuleFactory.sol";
import {MockBeneficiary} from "./mocks/MockBeneficiary.sol";

contract VestingModuleTest is DSTest {
    Vm public constant VM = Vm(HEVM_ADDRESS);

    VestingModuleFactory vmf;
    VestingModule vm;

    MockBeneficiary mb;

    event CreateVestingModule(
        address indexed beneficiary,
        uint256 vestingPeriod
    );

    function setUp() public {
        mb = new MockBeneficiary();
        vmf = new VestingModuleFactory(new VestingModule());
    }

    function testCan_createVestingModule(
        address beneficiary,
        uint256 vestingPeriod
    ) public {
        VM.assume(beneficiary != address(0));
        VM.assume(vestingPeriod != 0);

        VM.expectEmit(true, false, false, true);
        emit CreateVestingModule(beneficiary, vestingPeriod);

        vm = vmf.createVestingModule(beneficiary, vestingPeriod);

        assertEq(vm.beneficiary(), beneficiary);
        assertEq(vm.vestingPeriod(), vestingPeriod);
    }

    function testCannot_setBeneficiaryToAddressZero(uint256 vestingPeriod)
        public
    {
        VM.assume(vestingPeriod != 0);

        VM.expectRevert(VestingModuleFactory.InvalidBeneficiary.selector);

        vm = vmf.createVestingModule(address(0), vestingPeriod);
    }

    function testCannot_setVestingPeriodToZero(address beneficiary) public {
        VM.assume(beneficiary != address(0));
        VM.expectRevert(VestingModuleFactory.InvalidVestingPeriod.selector);

        vm = vmf.createVestingModule(beneficiary, 0);
    }
}
