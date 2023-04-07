// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin-contracts/token/ERC20/ERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";


contract Exchange is ERC20 {
    IERC20 public token; 
    constructor(address token_addr) ERC20("ExchangeToken", "XT") {
        token = IERC20 (token_addr);
    }
}