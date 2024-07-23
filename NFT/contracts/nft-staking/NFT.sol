// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IToken {
    function decimals() external returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract NFTToken is ERC721 {
    IToken metanaToken;
    uint256 public nftSupply;
    uint256 constant MAX_SUPPLY = 10;
    uint256 dec;

    constructor(address _token) ERC721("NFTToken", "NFT") {
        metanaToken = IToken(_token);
        dec = metanaToken.decimals();
    }

    function safeMint() external {
        require(
            price() <= tokenBalance(),
            "Not enough money, or not approved transaction."
        );
        require(nftSupply < MAX_SUPPLY, "All NFTs have been minted");
        metanaToken.transferFrom(msg.sender, address(this), price());
        _safeMint(msg.sender, nftSupply, "");
        nftSupply++;
    }

    function tokenBalance() public view returns (uint256) {
        return metanaToken.balanceOf(msg.sender);
    }

    function price() public view returns (uint256) {
        uint256 nftPrice = 10 * 10 ** dec;
        return nftPrice;
    }
}
