// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract rToken is ERC20, Ownable(msg.sender) {
    address public underlyingToken;

    constructor(
        address _underlyingToken,
        string memory _name,
        string memory _token
    ) ERC20(_name, _token) {
        underlyingToken = _underlyingToken;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _mint(from, amount);
    }
}
