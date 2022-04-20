// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import {Test} from "forge-std/Test.sol";
import {VestingModule} from "../VestingModule.sol";
import {VestingModuleFactory} from "../VestingModuleFactory.sol";
import {MockBeneficiary} from "./mocks/MockBeneficiary.sol";

contract VestingModuleTest is Test {
    VestingModuleFactory exampleVmf;
    VestingModule exampleVm;

    MockBeneficiary mb;

    event CreateVestingModule(
        address indexed vestingModule,
        address indexed beneficiary,
        uint256 vestingPeriod
    );

    function setUp() public {
        mb = new MockBeneficiary();
        exampleVmf = new VestingModuleFactory();
    }

    /// -----------------------------------------------------------------------
    /// correctness tests
    /// -----------------------------------------------------------------------

    function testCan_createVestingModule(
        address beneficiary,
        uint256 vestingPeriod
    ) public {
        vm.assume(beneficiary != address(0));
        vm.assume(vestingPeriod != 0);

        // can't predict address so don't check first indexed topic
        vm.expectEmit(false, true, true, true);
        emit CreateVestingModule(address(this), beneficiary, vestingPeriod);

        exampleVm = exampleVmf.createVestingModule(beneficiary, vestingPeriod);

        assertEq(exampleVm.beneficiary(), beneficiary);
        assertEq(exampleVm.vestingPeriod(), vestingPeriod);
    }

    function testCannot_setBeneficiaryToAddressZero(uint256 vestingPeriod)
        public
    {
        vm.assume(vestingPeriod != 0);

        vm.expectRevert(VestingModuleFactory.InvalidBeneficiary.selector);

        exampleVm = exampleVmf.createVestingModule(address(0), vestingPeriod);
    }

    function testCannot_setVestingPeriodToZero(address beneficiary) public {
        vm.assume(beneficiary != address(0));
        vm.expectRevert(VestingModuleFactory.InvalidVestingPeriod.selector);

        exampleVm = exampleVmf.createVestingModule(beneficiary, 0);
    }
}
