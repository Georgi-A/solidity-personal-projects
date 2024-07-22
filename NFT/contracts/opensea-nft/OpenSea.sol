// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTToken is ERC721 {
    uint256 nftSupply;
    uint256 constant MAX_SUPPLY = 10;
    string constant baseURI =
        "ipfs://QmY5ucvJYcgq9HyDMB5jEkAqpgWg1cSZoFNASh7govG86g/";

    constructor() ERC721("NFTToken", "NFT") {}

    function mint() external {
        require(nftSupply < MAX_SUPPLY, "All NFTs have been minted");
        _mint(msg.sender, nftSupply);
        nftSupply++;
    }

    function tokenURI(
        uint256 token
    ) public pure override returns (string memory) {
        return string.concat(baseURI, Strings.toString(token), ".txt");
    }
}