// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error AuctionDurationOutOfBounds(uint256 maxDuration, uint256 minDuration, uint256 duration);
error NotOwnerOfToken();

contract NFTAuction {
    enum Status {
        OPEN,
        CLOSED
    }

    struct Bidder {
        uint256 bidAmount;
        bool participated;
    }

    struct Auction {
        uint256 auctionId;
        IERC721 collectionContract;
        uint256 tokenId;
        address seller;
        uint256 deadline;
        IERC20 currency;
        uint256 reservePrice;
        uint256 highestBid;
        address highestBidder;
        Status status;
    }

    uint256 public constant MAX_DURATION = 1 days;
    uint256 public constant MIN_DURATION = 2 hours;
    uint256 public constant HALF_TOKEN = 5 * 10 ** 17;
    uint256 public constant FEE = 300;
    address public immutable owner;

    uint256 public auctionCount;
    IERC20[] private allowedCurrencies;
    mapping(IERC20 => bool) private currencies;
    mapping(address user => bool) private blackList;
    mapping(uint256 tokenId => Auction) private auctions;
    mapping(address bidder => mapping(uint256 auctionId => Bidder)) private bidders;
    mapping(address owner => mapping(IERC721 addressItem => uint256 tokenId)) private listedItems;
    mapping(address owner => mapping(IERC20 tokenAddress => uint256 feeAmount)) private ownerAccumulatedAmounts;

    constructor(IERC20[] memory _allowedCurrencies) {
        owner = msg.sender;

        for (uint256 i; i < _allowedCurrencies.length; i++) {
            currencies[_allowedCurrencies[i]] = true;
            allowedCurrencies.push(_allowedCurrencies[i]);
        }
    }

    modifier bidRequirements(uint256 auctionNumber, uint256 amount) {
        Auction memory auction = auctions[auctionNumber];
        require(auctionNumber == auction.auctionId, "Auction does not exist");
        require(block.timestamp <= auction.deadline, "Auction has finished");
        require(amount > 0, "Amount cannot be 0");
        require(amount > auction.reservePrice, "Auction amount lower than reservePrice");
        require(
            amount + bidders[msg.sender][auctionNumber].bidAmount > auction.highestBid, "Amount lower than higher bid"
        );
        require(IERC20(auction.currency).balanceOf(msg.sender) >= amount, "Not enough funds");
        _;
    }

    function listItem(
        IERC721 _collectionContract,
        uint256 _tokenId,
        uint256 _duration,
        IERC20 _currency,
        uint256 _reservePrice
    ) external {
        require(
            _duration >= MIN_DURATION && _duration <= MAX_DURATION,
            AuctionDurationOutOfBounds(MAX_DURATION, MIN_DURATION, _duration)
        );
        require(_collectionContract.ownerOf(_tokenId) == msg.sender, NotOwnerOfToken());
        require(_collectionContract != IERC721(address(0)), "Auction: Invalid collection contract");
        require(listedItems[msg.sender][_collectionContract] == 0, "Auction: Item already listed");
        require(_reservePrice > 0, "Auction: Reserve price must be greater than 0");
        require(currencies[_currency], "Auction: Currency not allowed");

        Auction memory _auction;
        _auction.auctionId = auctionCount;
        _auction.collectionContract = _collectionContract;
        _auction.tokenId = _tokenId;
        _auction.seller = msg.sender;
        _auction.deadline = block.timestamp + _duration;
        _auction.currency = _currency;
        _auction.reservePrice = _reservePrice;
        _auction.status = Status.OPEN;

        listedItems[msg.sender][_collectionContract] = _tokenId;
        auctions[auctionCount] = _auction;
        auctionCount++;

        //EVENT
    }

    function bid(uint256 auctionNumber, uint256 amount) external bidRequirements(auctionNumber, amount) {
        Auction storage auction = auctions[auctionNumber];
        auction.highestBid = amount;
        auction.highestBidder = msg.sender;

        bidders[msg.sender][auctionNumber].bidAmount += amount;

        if (!bidders[msg.sender][auctionNumber].participated) {
            bidders[msg.sender][auctionNumber].participated = true;
        }

        IERC20(auction.currency).transferFrom(msg.sender, address(this), amount);
        //EVENT
    }

    function bidOneTokenUp(uint256 auctionNumber) external {
        Auction storage auction = auctions[auctionNumber];
        require(auctionNumber == auction.auctionId, "Auction does not exist");
        require(block.timestamp <= auction.deadline, "Auction has finished");
        require(
            IERC20(auction.currency).balanceOf(msg.sender) + bidders[msg.sender][auctionNumber].bidAmount
                >= auction.highestBid + HALF_TOKEN,
            "Not enough funds"
        );

        uint256 amountToDeposit = (auction.highestBid + HALF_TOKEN) - bidders[msg.sender][auctionNumber].bidAmount;
        bidders[msg.sender][auctionNumber].bidAmount += amountToDeposit;

        auction.highestBid += HALF_TOKEN;
        auction.highestBidder = msg.sender;

        if (!bidders[msg.sender][auctionNumber].participated) {
            bidders[msg.sender][auctionNumber].participated = true;
        }

        IERC20(auction.currency).transferFrom(msg.sender, address(this), amountToDeposit);

        //EVENT
    }

    function sellerWithdraw(uint256 auctionNumber) external {
        Auction storage auction = auctions[auctionNumber];
        require(auctionNumber == auction.auctionId, "Auction does not exist");
        require(auction.seller == msg.sender, "Not owner of auction");
        require(auction.highestBid >= auction.reservePrice, "Reserve price not met");
        require(block.timestamp > auction.deadline, "Auction still open");
        require(
            IERC721(auction.collectionContract).ownerOf(auction.tokenId) == auction.highestBidder,
            "NFT has not been sent to bidder"
        );

        auction.status = Status.CLOSED;

        uint256 feeAmount = (auction.highestBid * FEE) / 10000;

        ownerAccumulatedAmounts[owner][auction.currency] += feeAmount;

        IERC20(auction.currency).transfer(msg.sender, auction.highestBid - feeAmount);

        //EVENT
    }

    function userWithdraw(uint256 auctionNumber) external {
        Auction memory auction = auctions[auctionNumber];
        require(auctionNumber == auction.auctionId, "Auction does not exist");
        require(auction.highestBidder != msg.sender, "You won auction, cannot withdraw");
        require(bidders[msg.sender][auctionNumber].bidAmount > 0, "You have not participated in auction");

        IERC20(auction.currency).transfer(msg.sender, bidders[msg.sender][auctionNumber].bidAmount);

        //EVENT
    }

    function blackListSeller(uint256 auctionNumber) external {
        Auction storage auction = auctions[auctionNumber];
        require(msg.sender == auction.highestBidder, "Not allowed to black list");
        require(IERC721(auction.collectionContract).ownerOf(auction.tokenId) != msg.sender, "You are the owner of NFT");

        if (
            block.timestamp >= auction.deadline + 24 hours
                || IERC721(auction.collectionContract).ownerOf(auction.tokenId) != auction.seller
        ) {
            blackList[auction.seller] = true;
            uint256 bidAmount = auction.highestBid;
            auction.status = Status.CLOSED;

            IERC20(auction.currency).transfer(msg.sender, bidAmount);
        }

        //EVENT
    }

    // TOKENSWAP IMPLEMENTATION

    function getOpenAuctions() external view returns (uint256[] memory openAuctions) {
        for (uint256 i; i < auctionCount; ++i) {
            if (auctions[i].status == Status.OPEN) {
                openAuctions[i] = i;
            }
        }
        return openAuctions;
    }

    function getAllowedCurrencies() external view returns (IERC20[] memory) {
        IERC20[] memory _currencies;
        for (uint256 i; i < allowedCurrencies.length; ++i) {
            _currencies[i] = allowedCurrencies[i];
        }
        return _currencies;
    }
}
