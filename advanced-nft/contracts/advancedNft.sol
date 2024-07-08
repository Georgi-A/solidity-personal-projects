// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract AdvancedNft is ERC721("AdvancedNFT", "ANFT") {
    // Events to log actions in the contract
    event Selected(address indexed _to, bytes32 _secret);
    event Minted(address indexed _to, uint256 indexed _tokenId);
    event BatchTransfered(
        address indexed _from,
        address[] indexed _to,
        uint256[] indexed _tokenIds
    );

    using BitMaps for BitMaps.BitMap;
    BitMaps.BitMap private _bitmap;

    // Enum to define the different stages of the NFT sale process
    enum Stages {
        EnterWhiteList,
        CoolDownPeriod,
        WhiteListSale,
        PublicSale,
        Closed
    }

    Stages public stage = Stages.EnterWhiteList; // Setting initial Stage

    // Struct to store the commitment information of users
    struct Commit {
        bytes32 secret;
        bool selected;
        uint256 mintedToken;
    }

    mapping(address => Commit) public commit; // Mapping to store user commitments
    mapping(address => uint256) public funds; // Mapping to store funds

    // Constants for price, total supply, and duration of stages
    uint256 constant PRICE = 1 ether;
    uint256 constant TOTAL_SUPPLY = 101;
    uint256 constant COOLDOWN_DURATION_BLOCKS = 10;
    uint256 constant OPEN_DURATION_BLOCKS = 15;
    uint256 immutable START_BLOCK;
    address private immutable owner; // Owner of the contract
    bytes32 private immutable root; // Root of the Merkle Tree for whitelist verification

    uint8 public supply = 1; // Current supply of NFTs
    uint8 private mintNftId = 1; // ID for the next NFT to be minted

    // Constructor to initialize the contract with the Merkle root and set the owner
    constructor(bytes32 _root) payable {
        root = _root;
        START_BLOCK = block.number;
        owner = msg.sender;
    }

    // Modifier to restrict access to the owner
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    // Modifier to ensure function is called at the correct stage
    modifier atStage(Stages _stage) {
        require(stage == _stage);
        _;
    }

    // Modifier to handle timed transitions between stages
    modifier timedTransitions() {
        if (
            stage == Stages.EnterWhiteList &&
            block.number >= START_BLOCK + OPEN_DURATION_BLOCKS
        ) {
            _nextStage();
        }

        if (
            stage == Stages.CoolDownPeriod &&
            block.number >=
            START_BLOCK + OPEN_DURATION_BLOCKS + COOLDOWN_DURATION_BLOCKS
        ) {
            _nextStage();
        }

        if (
            stage == Stages.WhiteListSale &&
            block.number >=
            START_BLOCK + 2 * OPEN_DURATION_BLOCKS + COOLDOWN_DURATION_BLOCKS
        ) {
            _nextStage();
        }

        if (stage == Stages.PublicSale && supply == TOTAL_SUPPLY) {
            _nextStage();
        }
        _;
    }

    // Function to enter White List
    function enterWhiteList(
        bytes32[] calldata _merkleProof,
        uint256 _index,
        bytes32 _secret
    ) external timedTransitions atStage(Stages.EnterWhiteList) {
        require(
            _getProof(_merkleProof, _index),
            "You are not part of the list!"
        );
        require(!commit[msg.sender].selected, "Already selected");

        commit[msg.sender].secret = _secret;
        commit[msg.sender].selected = true;

        emit Selected(msg.sender, _secret);
    }

    // Function to mint an NFT during the whitelist sale stage
    function whiteListMint(
        uint256 _number,
        uint256 _salt
    ) external payable timedTransitions atStage(Stages.WhiteListSale) {
        require(msg.value == 1 ether, "Cost is 1 ether");

        string memory id = Strings.toString(_number);
        string memory secret = Strings.toString(_salt);
        bytes32 combination = bytes32(
            keccak256(bytes(string.concat(id, secret)))
        );

        require(combination == commit[msg.sender].secret, "Wrong secret");
        require(commit[msg.sender].selected, "You have not selected NFT");
        require(!_bitmap.get(uint256(uint160(msg.sender))), "Already claimed!");

        uint256 userAddress = uint256(uint160(msg.sender));

        // Generate a random NFT ID
        uint8 random = uint8(
            uint256(keccak256(abi.encodePacked(combination, userAddress)))
        ) % uint8(TOTAL_SUPPLY);

        supply++;
        commit[msg.sender].mintedToken = random;
        _bitmap.set(uint256(uint160(msg.sender)));
        _safeMint(msg.sender, random);

        emit Minted(msg.sender, random);
    }

    // Function to mint an NFT during the public sale stage
    function publicMint()
        external
        payable
        timedTransitions
        atStage(Stages.PublicSale)
    {
        require(msg.value == 1 ether, "Cost is 1 ether");
        require(supply <= TOTAL_SUPPLY, "No NFTs left");

        // Find the next available NFT ID
        if (ownerOf(mintNftId) != address(0)) {
            while (ownerOf(mintNftId) != address(0)) {
                mintNftId++;
            }
        }

        supply++;
        _safeMint(msg.sender, mintNftId);

        emit Minted(msg.sender, mintNftId);
    }

    // Function to batch transfer multiple NFTs to multiple addresses
    function batchTransfer(
        address[] calldata targets,
        uint256[] calldata tokens
    ) external {
        require(
            targets.length == tokens.length,
            "Target and data should be same size"
        );

        for (uint i; i < targets.length; i++) {
            require(
                ownerOf(tokens[i]) == msg.sender,
                "You do not own that token"
            );

            _safeTransfer(msg.sender, targets[i], tokens[i]);
        }

        emit BatchTransfered(msg.sender, targets, tokens);
    }

    // Function for the owner to pull funds from the contract
    function pullFunds() external onlyOwner {
        funds[msg.sender] = address(this).balance;
    }

    // Function for the owner to withdraw funds to specified addresses
    function withdraw(
        address[] calldata receivers,
        uint256[] calldata amounts
    ) external payable onlyOwner returns (bool) {
        uint256 amount = funds[msg.sender];

        require(amount > 0, "Execute pullFunds() before withdraw");

        funds[msg.sender] = 0;

        require(
            receivers.length == amounts.length,
            "Receivers and amounts should be same size"
        );

        bool sent;

        for (uint i; i < receivers.length; i++) {
            require(address(this).balance >= amount, "Nothing to withdraw");

            (bool success, ) = receivers[i].call{value: amounts[i]}("");
            require(success, "Failed transaction");
            sent = success;
        }

        return sent;
    }

    // Function to get the token ID minted by the caller
    function getToken() external view returns (uint256) {
        return commit[msg.sender].mintedToken;
    }

    // Internal function to verify Merkle Proof
    function _getProof(
        bytes32[] calldata _merkleProof,
        uint256 _index
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(msg.sender, _index)))
        );

        return MerkleProof.verify(_merkleProof, root, leaf);
    }

    // Internal function to transition to the next stage
    function _nextStage() internal {
        stage = Stages(uint(stage) + 1);
    }

    // Overridden function to get the owner of a token
    // Its written as such so it checks if the current NFT is available or already minted
    function ownerOf(uint256 tokenId) public view override returns (address) {
        address tokenOwner = _ownerOf(tokenId);
        if (tokenOwner == address(0)) {
            return address(0);
        }
        return tokenOwner;
    }
}
