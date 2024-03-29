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
        dex.addLiquidity{value: 1000 ether}(1000 ether);
    }

    function test_initialize() public {
        // check reserves correctly initialized
        assertEq(dex.getEthReserve(), 1000 ether);
        assertEq(dex.getTokenReserve(), 1000 ether);

        // check LP tokens minted
        assertEq(dex.getTotalLiquidity(), 1000 ether);
        assertEq(dex.getLiquidity(deployer), 1000 ether);
    }

    function test_revert_InvalidTokenAddress() public {
        address invalidToken = address(0);
        Exchange e = new Exchange(invalidToken);
        vm.expectRevert("Invalid Token Contract");
        e.addLiquidity{value: 10 ether}(10 ether);
    }

    function test_addLiquidity() public {
        vm.expectEmit(true, false, false, true);
        emit AddLiquidity(user1, 1000 ether, 1000 ether);

        vm.prank(user1);
        dex.addLiquidity{value: 1000 ether}(1000 ether);

        assertEq(dex.getEthReserve(), 2000 ether);
        assertEq(dex.getTokenReserve(), 2000 ether);

        assertEq(dex.getTotalLiquidity(), 2000 ether);
        assertEq(dex.getLiquidity(user1), 1000 ether);
    }

    function test_revert_addLiquidity_WrongRatio() public {
        vm.expectRevert(
            "The amount of sent tokens does not cover the minimum amount required to maintain the ratio"
        );
        vm.prank(user1);
        dex.addLiquidity{value: 1000 ether}(900 ether);
    }

    function test_revert_addLiquidity_ZeroAmount() public {
        vm.expectRevert("Amount must be greater than Zero");
        dex.addLiquidity{value: 100 ether}(0);
    }

    function test_removeLiquidity() public {
        vm.expectEmit(true, false, false, true);
        emit RemoveLiquidity(deployer, 500 ether, 500 ether);

        uint oldEthUser = address(deployer).balance;
        uint oldTokenUser = token.balanceOf(deployer);

        dex.removeLiquidity(500 ether);

        assertEq(dex.getEthReserve(), 500 ether);
        assertEq(dex.getTokenReserve(), 500 ether);

        assertEq(dex.getTotalLiquidity(), 500 ether);
        assertEq(dex.getLiquidity(deployer), 500 ether);
        assertApproxEqAbs(address(deployer).balance, oldEthUser + 500 ether, 0);
        assertApproxEqAbs(
            token.balanceOf(deployer),
            oldTokenUser + 500 ether,
            0
        );
    }

    function test_revert_removeLiquidity_ZeroAmount() public {
        vm.expectRevert("Amount must be greater than Zero");
        dex.removeLiquidity(0);
    }

    function test_revert_removeLiquidity_ExceedUserOwned() public {
        vm.prank(user2);
        dex.addLiquidity{value: 1000 ether}(1000 ether);

        assertEq(dex.getTotalLiquidity(), 2000 ether);
        assertEq(dex.getLiquidity(deployer), 1000 ether);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        dex.removeLiquidity(1001 ether);
    }

    function test_revert_removeLiquidity_ExceedTotalSupply() public {
        dex.addLiquidity{value: 1000 ether}(1000 ether);
        assertEq(dex.getTotalLiquidity(), 2000 ether);
        vm.expectRevert("Transfer of assets failed");
        dex.removeLiquidity(2001 ether);
    }

    function test_revert_removeLiquidity_ZeroTotalSupply() public {
        // CASE 1
        // this can happen despite mathematically infinite reserves (xy=k)
        // because we don't check whether any liquidity removed is the last one
        dex.removeLiquidity(1000 ether); //
        assertEq(dex.getTotalLiquidity(), 0);
        vm.expectRevert("No liquidity to remove");
        dex.removeLiquidity(1);

        // CASE 2
        // when trying to remove liquidity from uninitialized DEX
        MyToken t = new MyToken(10);
        Exchange e = new Exchange(address(t));
        vm.expectRevert("No liquidity to remove");
        e.removeLiquidity(1);
    }

    function test_price() public {
        uint256 inputEth = 100 ether;
        uint256 expectedPrice1 = price(
            inputEth,
            dex.getEthReserve(),
            dex.getTokenReserve()
        );
        uint256 actualPrice1 = dex.price(
            inputEth,
            dex.getEthReserve(),
            dex.getTokenReserve()
        );
        assertEq(expectedPrice1, actualPrice1);
    }

    function test_price_AfterSwap() public {
        uint256 inputEth = 100 ether;
        dex.ethToToken{value: inputEth}(90 ether);
        uint256 expectedPrice1 = price(
            inputEth,
            dex.getEthReserve(),
            dex.getTokenReserve()
        );
        uint256 actualPrice1 = dex.price(
            inputEth,
            dex.getEthReserve(),
            dex.getTokenReserve()
        );
        assertEq(expectedPrice1, actualPrice1);

        dex.tokenToEth(100 ether, 100 ether);
        uint256 expectedPrice2 = price(
            inputEth,
            dex.getEthReserve(),
            dex.getTokenReserve()
        );
        uint256 actualPrice2 = dex.price(
            inputEth,
            dex.getEthReserve(),
            dex.getTokenReserve()
        );
        assertEq(expectedPrice2, actualPrice2);
    }

    function test_price_AfterLiquidityEvent() public {
        uint256 input = 1000 ether;
        uint256 inputEth = 100 ether;

        dex.addLiquidity{value: input}(input);
        uint256 expectedPrice1 = price(
            inputEth,
            dex.getEthReserve(),
            dex.getTokenReserve()
        );
        uint256 actualPrice1 = dex.price(
            inputEth,
            dex.getEthReserve(),
            dex.getTokenReserve()
        );
        assertEq(expectedPrice1, actualPrice1);

        dex.removeLiquidity(input);
        uint256 expectedPrice2 = price(
            inputEth,
            dex.getEthReserve(),
            dex.getTokenReserve()
        );
        uint256 actualPrice2 = dex.price(
            inputEth,
            dex.getEthReserve(),
            dex.getTokenReserve()
        );
        assertEq(expectedPrice2, actualPrice2);
    }

    function test_ethToToken() public {
        uint oldEthUser = address(deployer).balance;
        uint oldTokenUser = token.balanceOf(deployer);
        uint oldEthDex = dex.getEthReserve();
        uint oldTokenDex = dex.getTokenReserve();
        uint input = 100 ether;
        uint256 output = price(
            100 ether,
            dex.getEthReserve(),
            dex.getTokenReserve()
        );

        vm.expectEmit(true, true, true, true);
        emit BuyToken(deployer, input, output);

        dex.ethToToken{value: input}(90 ether);

        assertEq(dex.getEthReserve(), oldEthDex + input);
        assertEq(dex.getTokenReserve(), oldTokenDex - output);
        assertEq(address(deployer).balance, oldEthUser - input);
        assertEq(token.balanceOf(deployer), oldTokenUser + output);
    }

    function test_revert_ethToToken_InsufficientOutput() public {
        vm.expectRevert("Output amount not enough");
        dex.ethToToken{value: 100 ether}(100 ether);
    }

    function test_tokenToEth() public {
        uint oldEthUser = address(deployer).balance;
        uint oldTokenUser = token.balanceOf(deployer);
        uint oldEthDex = dex.getEthReserve();
        uint oldTokenDex = dex.getTokenReserve();
        uint input = 100 ether;
        uint256 output = price(
            100 ether,
            dex.getEthReserve(),
            dex.getTokenReserve()
        );

        vm.expectEmit(true, true, true, true);
        emit BuyEth(deployer, output, input);

        dex.tokenToEth(input, output);

        assertEq(dex.getEthReserve(), oldEthDex - output);
        assertEq(dex.getTokenReserve(), oldTokenDex + input);
        assertEq(address(deployer).balance, oldEthUser + output);
        assertEq(token.balanceOf(deployer), oldTokenUser - input);
    }

    function test_revert_tokenToEth_InsufficientOutput() public {
        vm.expectRevert("Output amount not enough");
        dex.tokenToEth(100 ether, 100 ether);
    }

    function test_SwapWithSlippage() public {
        // quick demonstration of slippage
        // the higher the traded amount in proportion to reserves, the higher the slippage (ie the less output amount)
        // just get all the funds here
        vm.deal(deployer, 25_000 ether);
        vm.prank(user1);
        token.transfer(deployer, 5000 ether);
        vm.prank(user2);
        token.transfer(deployer, 5000 ether);
        token.approve(address(dex), 14_000 ether);
        dex.addLiquidity{value: 14_000 ether}(14_000 ether);
        // ====> Reserves in pool: 15_000 ETH, 15_000 Tokens
        // ====> Traded amount: 10_000 ETH
        uint amount = 10_000 ether;
        uint256 output = price(amount, 15_000 ether, 15_000 ether);
        console.log(
            "Output amount from price function (formatted in ETH): ",
            output / (10 ** 18)
        );
        dex.ethToToken{value: amount}(output); // <=== we got about 60% of what we put in, 40% slippage 
    }

    function test_DemoOfLPToken() public {
        // mint new LP tokens
        dex.addLiquidity{value: 1000 ether}(1000 ether);
        vm.prank(user1);
        dex.addLiquidity{value: 3000 ether}(3000 ether);
        vm.prank(user2);
        dex.addLiquidity{value: 1000 ether}(1000 ether);
        // ====> LP tokens ratio: 1:2:3 (user2: deployer: user1)

        uint deployerEth = address(this).balance;
        uint deployerToken = token.balanceOf(address(this));
        uint user1Eth = address(user1).balance;
        uint user1Token = token.balanceOf(user1);
        uint user2Eth = address(user2).balance;
        uint user2Token = token.balanceOf(user2);

        // do some trades & collect fees
        dex.ethToToken{value: 2000 ether}(1400 ether);
        vm.prank(user1);
        token.approve(address(dex), 5000 ether);
        vm.prank(user1);
        dex.tokenToEth(3000 ether, 2700 ether);
        vm.prank(user2);
        dex.ethToToken{value: 1000 ether}(900 ether);

        // exchange LP token for liquidity and fees
        dex.removeLiquidity(2000 ether);
        // TODO
    }

    function price(
        uint256 _inAmount,
        uint256 _inReserve,
        uint256 _outReserve
    ) public pure returns (uint256 outAmount) {
        require(_inReserve > 0, "Insufficient input reserve");
        // constant product formula
        // (x + Δx) * (y - Δy) = x * y ==> Δy = x * y / (x + Δx) - y
        uint256 inAmountWithFee = _inAmount * 997; // 0.3% fee
        uint256 numerator = inAmountWithFee * _outReserve;
        uint256 denominator = (_inReserve * 1000) + inAmountWithFee;
        outAmount = numerator / denominator;
    }

    fallback() external payable {}

    receive() external payable {}
}
