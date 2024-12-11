// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./rToken.sol";

contract Deposit is Ownable(msg.sender) {
    mapping(address => ERC20) public tokens;
    mapping(address => rToken) public receiptTokens;

    constructor(address _aave, address _uni, address _weth) {
        tokens[_aave] = ERC20(_aave);
        tokens[_uni] = ERC20(_uni);
        tokens[_weth] = ERC20(_weth);

        receiptTokens[_aave] = new rToken(_aave, "receipt Aave token", "rAave");
        receiptTokens[_uni] = new rToken(_uni, "receipt Uni token", "rUni");
        receiptTokens[_weth] = new rToken(_weth, "receipt Weth token", "rWeth");
    }

    modifier isAllowedToken(address _token) {
        require(address(tokens[_token]) != address(0), "Token not allowed");
        _;
    }

    function deposit(address _token, uint256 _amount) external {
        bool sent = tokens[_token].transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        require(sent, "transaction failed");

        receiptTokens[_token].mint(msg.sender, _amount);
    }

    function withdraw(address _token, uint256 _amount) external {
        receiptTokens[_token].burn(msg.sender, _amount);

        bool sent = tokens[_token].transfer(msg.sender, _amount);
        require(sent, "transaction failed");
    }
}
