// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin-contracts/token/ERC20/ERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";

contract Exchange is ERC20 {
    IERC20 public token;

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

    constructor(address token_addr) ERC20("ExchangeToken", "XT") {
        token = IERC20(token_addr);
    }

    function addLiquidity(
        uint256 _maxAmount
    ) public payable returns (uint256 newLiquidity) {
        // the supply of LP token by the contract
        uint256 ethBalance = getEthReserve();
        // amount of tokens that are transferred to the contract
        uint256 tokenAmount;

        if (getTotalLiquidity() == 0) {
            // the first person to deposit liquidity can use an arbitrary ratio and set a price
            tokenAmount = _maxAmount;
            newLiquidity = ethBalance;
            require(token.transferFrom(msg.sender, address(this), tokenAmount));
            _mint(msg.sender, newLiquidity);

            emit AddLiquidity(msg.sender, msg.value, tokenAmount);
            emit Transfer(address(0), msg.sender, newLiquidity);
        } else {
            uint256 ethReserve = ethBalance - msg.value;
            // ensure that the ratio is maintained
            tokenAmount = (msg.value * getTokenReserve()) / ethReserve;
            require(
                _maxAmount >= tokenAmount,
                "The amount of sent tokens does not cover the minimum amount required to maintain the ratio"
            );
            require(token.transferFrom(msg.sender, address(this), tokenAmount));
            // determine new LP tokens to be minted by formula:
            // new LP / total LP = eth sent / eth reserve
            newLiquidity = (msg.value * getTotalLiquidity()) / ethReserve;
            _mint(msg.sender, newLiquidity);
            emit AddLiquidity(msg.sender, msg.value, tokenAmount);
            emit Transfer(address(0), msg.sender, newLiquidity);
        }
    }

    function getEthReserve() public view returns (uint256) {
        return address(this).balance;
    }

    function getTokenReserve() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getTotalLiquidity() public view returns (uint256) {
        return totalSupply();
    }

    function getLiquidity(address user) public view returns (uint256) {
        return balanceOf(user);
    }
}
