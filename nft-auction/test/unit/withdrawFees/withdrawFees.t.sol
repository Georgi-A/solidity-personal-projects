// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Base_Test } from "test/Base.t.sol";
import { Errors } from "src/utils/Errors.sol";
import { NFTAuction } from "src/NFTAuction.sol";

contract withdrawFees_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        vm.prank(sellerOne);
        succesfullAuction();
    }

    function test_RevertWhen_UserIsNotOwner(address user) external {
        vm.assume(user != owner);
        vm.prank(user);
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.OnlyOwner.selector
            )
        });
        nftAuction.withdrawFees(address(daiContract), reservePrice);
    }

    modifier whenUserIsOwner() {
        _;
    }

    function test_RevertGiven_CurrencyIsNotSupported(address currency) external whenUserIsOwner {
        vm.assume(currency != address(daiContract) && currency != address(wethContract));
        vm.prank(owner);
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.CurrencyNotSupported.selector
            )
        });
        nftAuction.withdrawFees(currency, 0);
    }

    modifier givenCurrencyIsSupported() {
        _;
    }

    function test_RevertGiven_InsufficientAmount(uint256 amount) external whenUserIsOwner givenCurrencyIsSupported {
        vm.startPrank(owner);
        vm.assume(amount > nftAuction.getAccumulatedFees(address(daiContract)));
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InsufficientFunds.selector,
                nftAuction.getAccumulatedFees(address(daiContract))
            )
        });
        nftAuction.withdrawFees(address(daiContract), amount);
    }

    function test_GivenSufficientAmount() external whenUserIsOwner givenCurrencyIsSupported {
        vm.startPrank(owner);
        uint256 ownerBalance = nftAuction.getAccumulatedFees(address(daiContract));
        // it should revert
        vm.expectEmit();
        emit NFTAuction.LogWithdrawFees(owner, address(daiContract), nftAuction.getAccumulatedFees(address(daiContract)));
        nftAuction.withdrawFees(address(daiContract), nftAuction.getAccumulatedFees(address(daiContract)));

        assertEq(ownerBalance, daiContract.balanceOf(owner));
        assertEq(nftAuction.getAccumulatedFees(address(daiContract)), 0);
    }
}
