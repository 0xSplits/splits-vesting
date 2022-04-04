// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

/* import {DSTest} from "ds-test/test.sol"; */
import "ds-test/test.sol";
import {stdError, stdStorage, stdCheats} from "forge-std/stdlib.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {VestingSplit} from "../VestingSplit.sol";
import {MockBeneficiary} from "./mocks/MockBeneficiary.sol";

contract VestingSplitTest is DSTest {
    Vm public constant VM = Vm(HEVM_ADDRESS);

    VestingSplit vs;
    MockBeneficiary mb;

    event CreateVestingSplit(
        address indexed beneficiary,
        uint256 vestingPeriod
    );

    function setUp() public {
        mb = new MockBeneficiary();
        vs = new VestingSplit(address(mb), 0);
        /* exampleToken = new MockERC20("Test Token", "TOK", 18); */
    }

    function testCan_createVestingSplit(
        address beneficiary,
        uint256 vestingPeriod
    ) public {
        VM.assume(beneficiary != address(0));
        vestingPeriod = vestingPeriod != 0 ? vestingPeriod : 365 days;

        VM.expectEmit(true, false, false, true);
        emit CreateVestingSplit(beneficiary, vestingPeriod);

        vs = new VestingSplit(beneficiary, vestingPeriod);
        assertEq(beneficiary, vs.beneficiary());
        assertEq(vs.vestingPeriod(), vestingPeriod);
    }

    function testCannot_setBeneficiaryToAddressZero(uint256 vestingPeriod)
        public
    {
        VM.expectRevert(VestingSplit.InvalidBeneficiary.selector);

        vs = new VestingSplit(address(0), vestingPeriod);
    }

    function testCan_receiveDeposit(uint96 deposit) public {
        (bool success, ) = address(vs).call{value: deposit}("");
        assertTrue(success);
        assertEq(address(vs).balance, deposit);
    }

    function testCan_addToVest(uint96 deposit) public {
        vestDeposit(deposit);

        assertEq(vs.vestingStart(), block.timestamp);
        assertEq(vs.vesting(), deposit);
        assertEq(vs.vestingClaimed(), 0);
        assertEq(vs.toBeClaimed(), 0);
        assertEq(vs.vestedAndUnclaimed(), 0);

        VM.warp(vs.vestingPeriod() / 2);
        assertEq(vs.vestedAndUnclaimed(), deposit / 2);

        VM.warp(vs.vestingPeriod());
        assertEq(vs.vestedAndUnclaimed(), deposit);
    }

    function testCan_claimFromVest(uint96 deposit) public {
        vestDeposit(deposit);
        VM.warp(vs.vestingPeriod());
        vs.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(vs.vesting(), deposit);
        assertEq(vs.vestingClaimed(), deposit);
        assertEq(vs.toBeClaimed(), 0);
        assertEq(vs.vestedAndUnclaimed(), 0);
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
        vs.addToVest();

        assertEq(vs.vestingStart(), depositGap);
        assertEq(vs.vesting(), deposit);
        assertEq(vs.vestingClaimed(), 0);
        assertEq(vs.toBeClaimed(), 0);
        assertEq(vs.vestedAndUnclaimed(), 0);
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
        VM.warp(vs.vestingPeriod() + depositGap);

        assertEq(vs.vestingStart(), depositGap);
        assertEq(vs.vesting(), uint256(deposit2) + deposit1 - uint256(deposit1) * depositGap / vs.vestingPeriod());
        assertEq(vs.vestingClaimed(), 0);
        assertEq(vs.toBeClaimed(),  uint256(deposit1) * depositGap / vs.vestingPeriod());
        assertEq(vs.vestedAndUnclaimed(), deposit);
    }

    function testCan_add_add_claim(uint48 deposit1, uint48 deposit2) public {
        uint256 deposit = uint256(deposit1) + uint256(deposit2);
        vestDeposit(deposit1);
        VM.warp(vs.vestingPeriod() / 2);
        vestDeposit(deposit2);
        VM.warp((vs.vestingPeriod() * 3) / 2);
        vs.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(vs.vesting(), uint256(deposit1) - deposit1 / 2 + deposit2);
        assertEq(
            vs.vestingClaimed(),
            uint256(deposit1) - deposit1 / 2 + deposit2
        );
        assertEq(vs.toBeClaimed(), 0);
        assertEq(vs.vestedAndUnclaimed(), 0);
    }

    function testCan_add_claim_add_claim(uint48 deposit1, uint48 deposit2) public {
        uint256 deposit = uint256(deposit1) + uint256(deposit2);
        vestDeposit(deposit1);
        VM.warp(vs.vestingPeriod() / 2);
        vs.claimFromVest();
        vestDeposit(deposit2);
        VM.warp((vs.vestingPeriod() * 3) / 2);
        vs.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(vs.vesting(), uint256(deposit1) - deposit1 / 2 + deposit2);
        assertEq(
                 vs.vestingClaimed(),
                 uint256(deposit1) - deposit1 / 2 + deposit2
                 );
        assertEq(vs.toBeClaimed(), 0);
        assertEq(vs.vestedAndUnclaimed(), 0);
    }

    function testCan_add_claim_add_claim_add_claim(uint48 deposit1, uint48 deposit2, uint48 deposit3) public {
        uint256 deposit = uint256(deposit1) + uint256(deposit2) + uint256(deposit3);
        vestDeposit(deposit1);
        VM.warp(vs.vestingPeriod() / 2);
        vs.claimFromVest();
        vestDeposit(deposit2);
        VM.warp(vs.vestingPeriod());
        vs.claimFromVest();
        vestDeposit(deposit3);
        VM.warp(2 * vs.vestingPeriod());
        vs.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(vs.toBeClaimed(), 0);
        assertEq(vs.vestedAndUnclaimed(), 0);
    }

    function testCan_add_claim_claim_claim(uint96 deposit) public {
        vestDeposit(deposit);

        VM.warp(vs.vestingPeriod() / 2);
        vs.claimFromVest();

        assertEq(address(mb).balance, deposit / 2);
        assertEq(vs.vesting(), deposit);
        assertEq(vs.vestingClaimed(), deposit / 2);
        assertEq(vs.toBeClaimed(), 0);
        assertEq(vs.vestedAndUnclaimed(), 0);

        VM.warp(vs.vestingPeriod());

        assertEq(address(mb).balance, deposit / 2);
        assertEq(vs.vesting(), deposit);
        assertEq(vs.vestingClaimed(), deposit / 2);
        assertEq(vs.toBeClaimed(), 0);
        assertEq(vs.vestedAndUnclaimed(), deposit - deposit / 2);

        vs.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(vs.vesting(), deposit);
        assertEq(vs.vestingClaimed(), deposit);
        assertEq(vs.toBeClaimed(), 0);
        assertEq(vs.vestedAndUnclaimed(), 0);

        VM.warp(vs.vestingPeriod() + 1);
        vs.claimFromVest();

        assertEq(address(mb).balance, deposit);
        assertEq(vs.vesting(), deposit);
        assertEq(vs.vestingClaimed(), deposit);
        assertEq(vs.toBeClaimed(), 0);
        assertEq(vs.vestedAndUnclaimed(), 0);
    }


    /// -----------------------------------------------------------------------
    /// functions - private & internal
    /// -----------------------------------------------------------------------

    function successfulDeposit(uint256 deposit) internal {
        (bool success, ) = address(vs).call{value: deposit}("");
        assertTrue(success);
    }

    function vestDeposit(uint256 deposit) internal {
        successfulDeposit(deposit);
        vs.addToVest();
    }
}
