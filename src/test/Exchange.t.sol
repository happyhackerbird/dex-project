pragma solidity >=0.8.0;

import "./BaseSetup.t.sol";

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

    function test_setUp() public {
        // check reserves correctly initialized
        assertEq(dex.getEthReserve(), 1000);
        assertEq(dex.getTokenReserve(), 1000);

        // check LP tokens minted
        assertEq(dex.getTotalLiquidity(), 1000);
        assertEq(dex.getLiquidity(deployer), 1000);
    }

    function test_addLiquidityAfterInitializing() public {
        vm.expectEmit(true, false, false, true);
        emit AddLiquidity(user1, 1000, 1000);

        vm.prank(user1);
        dex.addLiquidity{value: 1000}(1000);

        assertEq(dex.getEthReserve(), 2000);
        assertEq(dex.getTokenReserve(), 2000);

        assertEq(dex.getTotalLiquidity(), 2000);
        assertEq(dex.getLiquidity(user1), 1000);
    }

    function test_revert_addLiquidityWrongRatio() public {
        vm.expectRevert(
            "The amount of sent tokens does not cover the minimum amount required to maintain the ratio"
        );
        vm.prank(user1);
        dex.addLiquidity{value: 1000}(900);
    }
}
