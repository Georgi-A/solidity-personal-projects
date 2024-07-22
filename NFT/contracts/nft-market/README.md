# OpenWorld Smart Contract

## Overview

The OpenWorld smart contract is a decentralized marketplace for listing and purchasing ERC-721 NFTs. It ensures secure and transparent transactions between buyers and sellers.

## Features

- **List Items**: Users can list NFTs for sale.
- **Purchase Items**: Buyers can purchase listed NFTs with Ether.
- **Tracking**: Manages the status of all listed items.

## Contract Details

### Constants

- `maxPrice`: Maximum price for an item, set to 100 Ether.

### State Variables

- `itemsCounter`: Counter for total items listed.
- `listedItems`: Mapping of item IDs to `Item` structs.

### Structs

- `Item`: Represents a listed item.
  - `itemId`
  - `collectionContract`
  - `tokenId`
  - `price`
  - `seller`
  - `isSold`

### Functions

#### `listItem`

Lists an NFT for sale.

```solidity
function listItem(
    address _collectionAddr,
    uint256 _tokenId,
    uint256 _price
) external
```

- `_collectionAddr`: NFT collection address.
- `_tokenId`: NFT token ID.
- `_price`: Price in Ether.

**Requirements**:
- Transfers NFT from seller to contract.
- Increments `itemsCounter`.
- Stores new `Item` in `listedItems`.

#### `purchase`

Purchases a listed NFT.

```solidity
function purchase(uint256 _itemId) external payable
```

- `_itemId`: ID of the item to purchase.

**Requirements**:
- Item must not be sold.
- Item must exist.
- Sent Ether must match item price.
- Transfers NFT to buyer.
- Sends Ether to seller.
- Marks item as sold.

## Usage

### Listing an Item

Call `listItem` with collection contract address, token ID, and price.

```solidity
openWorld.listItem(collectionAddress, tokenId, price);
```

### Purchasing an Item

Call `purchase` with the item ID and send the exact Ether amount.

```solidity
openWorld.purchase{value: itemPrice}(itemId);
```

## Notes

- Ensure correct contract address and token ID before listing.
- Uses OpenZeppelin `IERC721` interface for NFT transfers.
- Not compatible with ERC-1155 tokens.

## License

Licensed under the MIT License