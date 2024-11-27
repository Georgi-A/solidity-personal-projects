// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.8.28;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    uint8 internal _decimals;

    constructor(
        string memory name,
        string memory symbol
    )
        ERC721(name, symbol)
    {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}