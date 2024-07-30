// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MetanaToken is ERC20, Ownable(msg.sender) {
    constructor() ERC20("MetanaToken", "MNT") {}

    function mint(address to, uint256 value) external onlyOwner {
        _mint(to, value);
    }
}
