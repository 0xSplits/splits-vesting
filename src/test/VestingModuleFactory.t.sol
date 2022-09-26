// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {VestingModule} from "../VestingModule.sol";
import {VestingModuleFactory} from "../VestingModuleFactory.sol";
import {MockBeneficiary} from "./mocks/MockBeneficiary.sol";

contract VestingModuleTest is Test {
    error CreateFail();

    event CreateVestingModule(
        address indexed vestingModule,
        address indexed beneficiary,
        uint256 vestingPeriod
    );

    VestingModuleFactory exampleVmf;
    VestingModule exampleVm;

    MockBeneficiary mb;

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
        function testCan_predictVestingModuleAddress(
        address beneficiary,
        uint256 vestingPeriod
    ) public {
        vm.assume(beneficiary != address(0));
        vm.assume(vestingPeriod != 0);

        (address predictedAddress, bool exists) = exampleVmf
            .predictVestingModuleAddress(beneficiary, vestingPeriod);

        assertTrue(!exists);

        exampleVm = exampleVmf.createVestingModule(beneficiary, vestingPeriod);
        assertEq(address(exampleVm), predictedAddress);

        (predictedAddress, exists) = exampleVmf.predictVestingModuleAddress(
            beneficiary,
            vestingPeriod
        );
        assertEq(address(exampleVm), predictedAddress);
        assertTrue(exists);
    }

    function testCannot_duplicateVestingModulesWithSameParams(
                                                 address beneficiary,
                                                 uint256 vestingPeriod
                                                 ) public {
        vm.assume(beneficiary != address(0));
        vm.assume(vestingPeriod != 0);

        exampleVm = exampleVmf.createVestingModule(beneficiary, vestingPeriod);

        vm.expectRevert(CreateFail.selector);

        exampleVm = exampleVmf.createVestingModule(beneficiary, vestingPeriod);
    }
}
