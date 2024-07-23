// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IMetanaToken {
    function mint(address to, uint256 value) external;

    function decimals() external returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);
}

contract Staking is IERC721Receiver {
    IMetanaToken public token;
    IERC721 public nftItem;
    uint256 private dec;

    mapping(uint256 => address) public nftOwner;
    mapping(uint256 => uint256) public tokenStakeAt;

    constructor(address _token, address _nftItem) {
        token = IMetanaToken(_token);
        nftItem = IERC721(_nftItem);
        dec = token.decimals();
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        require(msg.sender == address(nftItem));
        nftOwner[tokenId] = from;
        tokenStakeAt[tokenId] = block.timestamp;
        return IERC721Receiver.onERC721Received.selector;
    }

    function currentStake(uint256 tokenId) public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - tokenStakeAt[tokenId];
        return (timeElapsed * 10 * 10 ** dec) / 24 hours;
    }

    function withdraw(uint256 tokenId) external {
        require(nftOwner[tokenId] == msg.sender, "You are not the owner");
        token.mint(msg.sender, currentStake(tokenId));
        nftItem.transferFrom(address(this), msg.sender, tokenId);
        delete nftOwner[tokenId];
        delete tokenStakeAt[tokenId];
    }
}
