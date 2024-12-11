# AdvancedNFT Smart Contract

## Overview
The `AdvancedNFT` smart contract is an ERC721-based NFT implementation with advanced features such as Merkle tree-based whitelist verification, commit-reveal scheme for random NFT allocation, batch transfers, and a state machine for managing different sale phases. It also includes mechanisms for secure fund withdrawals using the pull over push pattern.

## Requirements
1. Implement a merkle tree airdrop where addresses in the merkle tree are allowed to mint once.
2. Use commit reveal to allocate NFT ids randomly. The reveal should be 10 blocks ahead of the commit. 
3. Add multicall to the NFT so people can transfer several NFTs in one transaction 
4. The NFT should use a state machine to determine if it is mints can happen, the presale is active, or the public sale is active, or the supply has run out.
5. Designated address should be able to withdraw funds using the pull pattern. You should be able to withdraw to an arbitrary number of contributors

## Features
1. **Merkle Tree Whitelist**: Only addresses in the Merkle tree are allowed to mint once. The Merkle leaf is the hash of the address and its index in the bitmap.
2. **Commit-Reveal Scheme**: Allocates NFT IDs randomly using a commit-reveal scheme that ensures fairness and unpredictability.
3. **Batch Transfer**: Allows users to transfer multiple NFTs in one transaction, enhancing efficiency and saving gas fees.
4. **State Machine**: Manages the sale phases (EnterWhiteList, CoolDownPeriod, WhiteListSale, PublicSale, Closed) to ensure orderly and secure minting processes.
5. **Pull Pattern for Withdrawals**: Ensures secure fund withdrawals to multiple addresses using the pull pattern.

## Contract Details

### Events
- `Selected(address indexed _to, bytes32 _secret)`: Emitted when an NFT is selected by a user.
- `Minted(address indexed _to, uint256 indexed _tokenId)`: Emitted when an NFT is minted.
- `BatchTransfered(address indexed _from, address[] indexed _to, uint256[] indexed _tokenIds)`: Emitted when multiple NFTs are transferred in a batch.

### Stages
- `EnterWhiteList`: Stage where users can enter the whitelist using the Merkle proof (commit).
- `CoolDownPeriod`: Cooldown period after the whitelist entry.
- `WhiteListSale`: Whitelisted users can mint their selected NFTs (reveal).
- `PublicSale`: Open sale where any user can mint NFTs.
- `Closed`: Sale is closed.

### Functions
- `enterWhiteList(bytes32[] calldata _merkleProof, uint256 _index, bytes32 _secret)`: Allows whitelisted users to enter the whitelist.
- `whiteListMint(uint256 _number, uint256 _salt)`: Allows whitelisted users to mint an NFT after the commit-reveal period.
- `publicMint()`: Allows any user to mint an NFT during the public sale stage.
- `batchTransfer(address[] calldata targets, uint256[] calldata tokens)`: Allows batch transfer of multiple NFTs.
- `pullFunds()`: Allows the owner to pull funds from the contract.
- `withdraw(address[] calldata receivers, uint256[] calldata amounts)`: Allows the owner to withdraw funds to multiple addresses securely.
- `getToken()`: Returns the token ID minted by the caller.
- `ownerOf(uint256 tokenId)`: Returns the owner of a given token ID, checking if the token is already minted.

