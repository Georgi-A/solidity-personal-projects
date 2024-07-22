// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract OpenWorld {
    uint256 public constant maxPrice = 100 ether;
    uint256 public itemsCounter;

    struct Item {
        uint256 itemId;
        address collectionContract;
        uint256 tokenId;
        uint256 price;
        address payable seller;
        bool isSold;
    }

    mapping(uint256 => Item) public listedItems;

    function listItem(
        address _collectionAddr,
        uint256 _tokenId,
        uint256 _price
    ) external {
        require(_collectionAddr != address(0), "Incorrect collection address");

        itemsCounter++;
        IERC721(_collectionAddr).transferFrom(
            msg.sender,
            address(this),
            _tokenId
        );
        Item collection = new Item(
            itemsCounter,
            _collectionAddr,
            _tokenId,
            _price,
            msg.sender,
            false
        );
        listedItems[itemId] = collection;
    }

    function purchase(uint256 _itemId) external payable {
        require(listedItems[_itemId].isSold != true, "Item sold");
        require(listedItems[_itemId] != 0, "Item does not exist");
        require(
            msg.value == listedItems[_itemId].price,
            "Amount does not match"
        );

        listedItems[_itemId].isSold = true;
        listedItems[_itemId].collectionContract.transferFrom(
            listedItems[_itemId].seller,
            msg.sender,
            listedItems[_itemId].tokenId
        );
        listedItems[_itemId].seller.call{value: listedItems[_itemId].price}(
            "Item sold"
        );
    }
}
