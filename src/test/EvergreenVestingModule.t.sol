// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

/* import {DSTest} from "ds-test/test.sol"; */
import "ds-test/test.sol";
import {stdError, stdStorage, stdCheats} from "forge-std/stdlib.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {EvergreenVestingModule} from "../EvergreenVestingModule.sol";
import {MockBeneficiary} from "./mocks/MockBeneficiary.sol";

contract EvergreenVestingModuleTest is DSTest {
    Vm public constant VM = Vm(HEVM_ADDRESS);

    EvergreenVestingModule evm;
    MockBeneficiary mb;

    event CreateEvergreenVestingModule(
        address indexed beneficiary,
        uint256 vestingPeriod
    );

    function setUp() public {
        mb = new MockBeneficiary();
        evm = new EvergreenVestingModule(address(mb), 0);
        /* exampleToken = new MockERC20("Test Token", "TOK", 18); */
    }

    function testCan_createEvergreenVestingModule(
        address beneficiary,
        uint256 vestingPeriod
    ) public {
        VM.assume(beneficiary != address(0));
        vestingPeriod = vestingPeriod != 0 ? vestingPeriod : 365 days;

        VM.expectEmit(true, false, false, true);
        emit CreateEvergreenVestingModule(beneficiary, vestingPeriod);

        evm = new EvergreenVestingModule(beneficiary, vestingPeriod);
        assertEq(beneficiary, evm.beneficiary());
        assertEq(evm.vestingPeriod(), vestingPeriod);
    }

    function testCannot_setBeneficiaryToAddressZero(uint256 vestingPeriod)
        public
    {
        VM.expectRevert(EvergreenVestingModule.InvalidBeneficiary.selector);

        evm = new EvergreenVestingModule(address(0), vestingPeriod);
    }

    function testCan_receiveDeposit(uint96 deposit) public {
        (bool success, ) = address(evm).call{value: deposit}("");
        assertTrue(success);
        assertEq(address(evm).balance, deposit);
    }

    function testCan_addToVest(uint96 deposit) public {
        vestDeposit(deposit);

        assertEq(evm.vestingStart(), block.timestamp);
        assertEq(evm.vesting(), deposit);
        assertEq(evm.vestingClaimed(), 0);
        assertEq(evm.toBeClaimed(), 0);
        assertEq(evm.vestedAndUnclaimed(), 0);

        VM.warp(evm.vestingPeriod() / 2);
        assertEq(evm.vestedAndUnclaimed(), deposit / 2);

        VM.warp(evm.vestingPeriod());
        assertEq(evm.vestedAndUnclaimed(), deposit);
    }

    function testCan_claimFromVest(uint96 deposit) public {
        vestDeposit(deposit);
        VM.warp(evm.vestingPeriod());
        evm.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(evm.vesting(), deposit);
        assertEq(evm.vestingClaimed(), deposit);
        assertEq(evm.toBeClaimed(), 0);
        assertEq(evm.vestedAndUnclaimed(), 0);
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
        evm.addToVest();

        assertEq(evm.vestingStart(), depositGap);
        assertEq(evm.vesting(), deposit);
        assertEq(evm.vestingClaimed(), 0);
        assertEq(evm.toBeClaimed(), 0);
        assertEq(evm.vestedAndUnclaimed(), 0);
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
        VM.warp(evm.vestingPeriod() + depositGap);

        assertEq(evm.vestingStart(), depositGap);
        assertEq(
            evm.vesting(),
            uint256(deposit2) +
                deposit1 -
                (uint256(deposit1) * depositGap) /
                evm.vestingPeriod()
        );
        assertEq(evm.vestingClaimed(), 0);
        assertEq(
            evm.toBeClaimed(),
            (uint256(deposit1) * depositGap) / evm.vestingPeriod()
        );
        assertEq(evm.vestedAndUnclaimed(), deposit);
    }

    function testCan_add_add_claim(uint48 deposit1, uint48 deposit2) public {
        uint256 deposit = uint256(deposit1) + uint256(deposit2);
        vestDeposit(deposit1);
        VM.warp(evm.vestingPeriod() / 2);
        vestDeposit(deposit2);
        VM.warp((evm.vestingPeriod() * 3) / 2);
        evm.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(evm.vesting(), uint256(deposit1) - deposit1 / 2 + deposit2);
        assertEq(
            evm.vestingClaimed(),
            uint256(deposit1) - deposit1 / 2 + deposit2
        );
        assertEq(evm.toBeClaimed(), 0);
        assertEq(evm.vestedAndUnclaimed(), 0);
    }

    function testCan_add_claim_add_claim(uint48 deposit1, uint48 deposit2)
        public
    {
        uint256 deposit = uint256(deposit1) + uint256(deposit2);
        vestDeposit(deposit1);
        VM.warp(evm.vestingPeriod() / 2);
        evm.claimFromVest();
        vestDeposit(deposit2);
        VM.warp((evm.vestingPeriod() * 3) / 2);
        evm.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(evm.vesting(), uint256(deposit1) - deposit1 / 2 + deposit2);
        assertEq(
            evm.vestingClaimed(),
            uint256(deposit1) - deposit1 / 2 + deposit2
        );
        assertEq(evm.toBeClaimed(), 0);
        assertEq(evm.vestedAndUnclaimed(), 0);
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
        VM.warp(evm.vestingPeriod() / 2);
        evm.claimFromVest();
        vestDeposit(deposit2);
        VM.warp(evm.vestingPeriod());
        evm.claimFromVest();
        vestDeposit(deposit3);
        VM.warp(2 * evm.vestingPeriod());
        evm.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(evm.toBeClaimed(), 0);
        assertEq(evm.vestedAndUnclaimed(), 0);
    }

    function testCan_add_claim_claim_claim(uint96 deposit) public {
        vestDeposit(deposit);

        VM.warp(evm.vestingPeriod() / 2);
        evm.claimFromVest();

        assertEq(address(mb).balance, deposit / 2);
        assertEq(evm.vesting(), deposit);
        assertEq(evm.vestingClaimed(), deposit / 2);
        assertEq(evm.toBeClaimed(), 0);
        assertEq(evm.vestedAndUnclaimed(), 0);

        VM.warp(evm.vestingPeriod());

        assertEq(address(mb).balance, deposit / 2);
        assertEq(evm.vesting(), deposit);
        assertEq(evm.vestingClaimed(), deposit / 2);
        assertEq(evm.toBeClaimed(), 0);
        assertEq(evm.vestedAndUnclaimed(), deposit - deposit / 2);

        evm.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(evm.vesting(), deposit);
        assertEq(evm.vestingClaimed(), deposit);
        assertEq(evm.toBeClaimed(), 0);
        assertEq(evm.vestedAndUnclaimed(), 0);

        VM.warp(evm.vestingPeriod() + 1);
        evm.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(evm.vesting(), deposit);
        assertEq(evm.vestingClaimed(), deposit);
        assertEq(evm.toBeClaimed(), 0);
        assertEq(evm.vestedAndUnclaimed(), 0);
    }

    /// -----------------------------------------------------------------------
    /// functions - private & internal
    /// -----------------------------------------------------------------------

    function successfulDeposit(uint256 deposit) internal {
        (bool success, ) = address(evm).call{value: deposit}("");
        assertTrue(success);
    }

    function vestDeposit(uint256 deposit) internal {
        successfulDeposit(deposit);
        evm.addToVest();
    }
}
