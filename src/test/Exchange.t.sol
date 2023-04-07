pragma solidity >=0.8.0;

import "./BaseSetup.t.sol";
import {console} from "./utils/Console.sol";

contract ExchangeTest is BaseSetup {
    event AddLiquidity(
        address indexed user,
        uint256 ethAmount,
        uint256 tokenAmount
    );
    event RemoveLiquidity(
        address indexed user,
        uint256 ethAmount,
        uint256 tokenAmount
    );
    event BuyToken(address indexed user, uint256 ethBought, uint256 tokenSold);
    event BuyEth(address indexed user, uint256 ethSold, uint256 tokenBought);

    function setUp() public {
        dex.addLiquidity{value: 1000}(1000);
    }

    function test_initialize() public {
        // check reserves correctly initialized
        assertEq(dex.getEthReserve(), 1000);
        assertEq(dex.getTokenReserve(), 1000);

        // check LP tokens minted
        assertEq(dex.getTotalLiquidity(), 1000);
        assertEq(dex.getLiquidity(deployer), 1000);
    }

    function test_addLiquidity() public {
        vm.expectEmit(true, false, false, true);
        emit AddLiquidity(user1, 1000, 1000);

        vm.prank(user1);
        dex.addLiquidity{value: 1000}(1000);

        assertEq(dex.getEthReserve(), 2000);
        assertEq(dex.getTokenReserve(), 2000);

        assertEq(dex.getTotalLiquidity(), 2000);
        assertEq(dex.getLiquidity(user1), 1000);
    }

    function test_revert_addLiquidity_WrongRatio() public {
        vm.expectRevert(
            "The amount of sent tokens does not cover the minimum amount required to maintain the ratio"
        );
        vm.prank(user1);
        dex.addLiquidity{value: 1000}(900);
    }

    function test_removeLiquidity() public {
        vm.expectEmit(true, false, false, true);
        emit RemoveLiquidity(deployer, 500, 500);

        dex.removeLiquidity(500);

        assertEq(dex.getEthReserve(), 500);
        assertEq(dex.getTokenReserve(), 500);

        assertEq(dex.getTotalLiquidity(), 500);
        assertEq(dex.getLiquidity(deployer), 500);
    }

    function test_revert_removeLiquidity_ZeroAmount() public {
        vm.expectRevert("Amount must be greater than Zero");
        dex.removeLiquidity(0);
    }

    function test_revert_removeLiquidity_ExceedUserOwned() public {
        vm.prank(user2);
        dex.addLiquidity{value: 1000}(1000);

        assertEq(dex.getTotalLiquidity(), 2000);
        assertEq(dex.getLiquidity(deployer), 1000);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        dex.removeLiquidity(1001);
    }

    function test_revert_removeLiquidity_ExceedTotalSupply() public {
        dex.addLiquidity{value: 1000}(1000);
        assertEq(dex.getTotalLiquidity(), 2000);
        vm.expectRevert("Transfer of assets failed");
        dex.removeLiquidity(2001);
    }

    // TODO would this even happen, 0 LP, with xy=k
    function test_revert_removeLiquidty_ZeroTotalSupply() public {
        dex.removeLiquidity(1000);
        assertEq(dex.getTotalLiquidity(), 0);
        vm.expectRevert("No liquidity to remove");
        dex.removeLiquidity(1);
    }

    function test_price() public {}

    fallback() external payable {}

    receive() external payable {}
}
