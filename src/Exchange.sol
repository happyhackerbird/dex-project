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
            // determine new LP tokens to be minted by ratio:
            // new LP / total LP = eth sent / eth reserve
            newLiquidity = (msg.value * getTotalLiquidity()) / ethReserve;
            _mint(msg.sender, newLiquidity);
            emit AddLiquidity(msg.sender, msg.value, tokenAmount);
            emit Transfer(address(0), msg.sender, newLiquidity);
        }
    }

    function removeLiquidity(
        uint256 _amount
    ) public returns (uint256 ethAmount, uint256 tokenAmount) {
        // other checks are not necessary here
        // because of _amount <= getLiquidity(msg.sender) <= getTotalLiquidity() and the first invariant will be checked by the _burn function
        require(_amount > 0, "Amount must be greater than Zero");
        uint256 totalLiquidity = getTotalLiquidity();
        require(totalLiquidity > 0, "No liquidity to remove");
        // the amount of respective tokens to be sent to the user is determined by the ratio:
        // amount of tokens to be sent / token reserve = liquidity to be removed / total liquidity
        ethAmount = (getEthReserve() * _amount) / totalLiquidity;
        tokenAmount = (getTokenReserve() * _amount) / totalLiquidity;
        (bool sent, ) = payable(msg.sender).call{value: ethAmount}("");
        require(sent, "Transfer of assets failed"); // these would also revert if more than the total available liquidity is specified
        require(
            token.transfer(msg.sender, tokenAmount),
            "Transfer of assets failed"
        );
        _burn(msg.sender, _amount); // this will revert if the specified liquidity is more than the user owns
        emit RemoveLiquidity(msg.sender, ethAmount, tokenAmount);
        emit Transfer(msg.sender, address(0), _amount);
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
