// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTToken is ERC721, Ownable(msg.sender) {
    uint256 public nftSupply;
    uint256 constant MAX_SUPPLY = 100;

    constructor(address _token) ERC721("NFTToken", "NFT") {}

    function safeMint() external payable {
        require(msg.value == 0.2 ether, "Mint requires 2 eth");
        nftSupply++;
        require(nftSupply <= MAX_SUPPLY, "All NFTs have been minted");
        _safeMint(msg.sender, nftSupply, "");
    }

    function withdraw() external onlyOwner {
        (bool sent, ) = msg.sender.call{value: address(this).balance}("");
        require(sent, "Transaction failed");
    }
}
