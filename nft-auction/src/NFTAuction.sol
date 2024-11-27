// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.8.28;

import { Errors } from "src/utils/Errors.sol";

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title English Auction for NFTs
/// @notice This smart contract allows users to sell and bid on NFTs. Owner receives 0.3% for each sold NFT.
/// @dev The smart contract does not hold ERC721 tokens. Instead, expects seller to send NFT to highest bidder within 1 day after the auction has finished.
/// In case seller does not send the NFT to the buyer or NFT has changed owner outside auction, seller will be blacklisted and will not be allowed to sell anymore,
/// while buyer/bidder will receive refund for that auction. Payments are done with ERC20 tokens, seller can select from allowed currencies. Also bidders can swap tokens within smart contract.
/// 'swapTokens' function uses Chainlink Oracle integration.
contract NFTAuction {
    using SafeERC20 for IERC20;

    event LogCreateAuction(
        address indexed seller, address indexed collectionContract, uint256 indexed tokenId, uint256 deadline
    );
    event LogBid(address indexed bidder, uint256 indexed highestBid, uint256 amount);
    event LogBidHalfTokenUp(address indexed bidder, uint256 indexed highestBid, uint256 amount);
    event LogSellerWithdraw(address indexed seller, uint256 amount, uint256 feeAmount);
    event LogBidderWithdraw(address indexed bidder, uint256 refund);
    event LogBlackListSeller(address indexed bidder, address indexed seller, uint256 refund);
    event LogWithdrawFees(address indexed owner, address indexed currency, uint256 amount);

    /// @notice Status of auction
    enum Status {
        OPEN,
        CLOSED
    }

    /// @param auctionId The id of auction
    /// @param collectionContract The address of NFT
    /// @param tokenId The id of token
    /// @param seller Address of seller
    /// @param deadline The end time of auction
    /// @param currency ERC20 token used for payment
    /// @param reservePrice The ask price
    /// @param highestBid Current highest bid
    /// @param highestBidder Current auction winner
    /// @param status Status of auction
    struct Auction {
        uint256 auctionId;
        address collectionContract;
        uint256 tokenId;
        address seller;
        uint256 deadline;
        address currency;
        uint256 reservePrice;
        uint256 highestBid;
        address highestBidder;
        Status status;
    }

    /// the maximum time an item can be listed for
    uint256 public constant MAX_DURATION = 1 days;
    /// the minimum time an item can be listed for
    uint256 public constant MIN_DURATION = 2 hours;
    /// used in 'bidHalfTokenUp' function, allowing bidder to directly outbid by half token
    uint256 public constant HALF_TOKEN = 5 * 10 ** 17;
    /// fee for sold NFT - 0.3%
    uint256 public constant FEE = 300;
    /// owner of smart contract
    address public immutable owner;

    /// total auctions count
    uint256 public auctionCount;
    /// Allowed currencies to trade with
    address[] private allowedCurrencies;
    /// Needed for check if currency is allowed
    mapping(address => bool) public currencies;
    /// Records blacklisted sellers
    mapping(address seller => bool) private blackList;
    /// Auction where seller was blacklisted
    mapping(address seller => uint256 actionId) private blacklistedFor;
    /// Auction state
    mapping(uint256 auctionId => Auction) private auctions;
    /// Records bidder current bid amounts
    mapping(address bidder => mapping(uint256 auctionId => uint256 amount)) private bidders;
    /// Records seller listed items
    mapping(address seller => mapping(address addressItem => uint256 tokenId)) private listedItems;
    /// Records the accumulated fees of owner
    mapping(address tokenAddress => uint256 feeAmount) private ownerAccumulatedFees;

    constructor(IERC20[] memory _allowedCurrencies) {
        owner = msg.sender;

        // Feed in allowed currencies
        for (uint256 i; i < _allowedCurrencies.length; i++) {
            currencies[address(_allowedCurrencies[i])] = true;
            allowedCurrencies.push(address(_allowedCurrencies[i]));
        }
    }

    modifier onlyOwner() {
        require(msg.sender == owner, Errors.OnlyOwner());
        _;
    }

    modifier createAuctionRequirements(
        address collectionContract,
        uint256 tokenId,
        uint256 duration,
        address currency,
        uint256 reservePrice
    ) {
        require(
            duration >= MIN_DURATION && duration <= MAX_DURATION,
            Errors.AuctionDurationOutOfBounds(MIN_DURATION, MAX_DURATION)
        );
        require(
            IERC721(collectionContract).ownerOf(tokenId) == msg.sender,
            Errors.NotOwnerOfToken(IERC721(collectionContract).ownerOf(tokenId))
        );
        require(listedItems[msg.sender][collectionContract] == 0, Errors.ItemAlreadyListed());
        require(reservePrice > 0, Errors.ZeroInput());
        require(currencies[currency], Errors.CurrencyNotAllowed());
        _;
    }

    modifier bidRequirements(uint256 auctionId, uint256 amount) {
        Auction memory _auction = auctions[auctionId];
        require(auctionId == _auction.auctionId, Errors.AuctionDoesNotExist());
        require(block.timestamp <= _auction.deadline, Errors.AuctionFinished(_auction.deadline));
        require(amount > 0, Errors.ZeroInput());
        require(
            amount + bidders[msg.sender][auctionId] > _auction.highestBid,
            Errors.PriceNotMet(_auction.highestBid, amount)
        );
        require(
            IERC20(_auction.currency).balanceOf(msg.sender) >= amount,
            Errors.InsufficientFunds(IERC20(_auction.currency).balanceOf(msg.sender))
        );
        _;
    }

    /// @notice Creates an auction
    /// @param collectionContract address of NFT
    /// @param tokenId ID of token
    /// @param duration Deadline for auction - in hours
    /// @param currency ERC20 token for payment
    /// @param reservePrice The asking price for NFT
    function createAuction(
        address collectionContract,
        uint256 tokenId,
        uint256 duration,
        address currency,
        uint256 reservePrice
    ) external createAuctionRequirements(collectionContract, tokenId, duration, currency, reservePrice) {
        Auction memory _auction;
        _auction.auctionId = auctionCount;
        _auction.collectionContract = collectionContract;
        _auction.tokenId = tokenId;
        _auction.seller = msg.sender;
        _auction.deadline = block.timestamp + (duration * 1 hours);
        _auction.currency = currency;
        _auction.reservePrice = reservePrice;
        _auction.status = Status.OPEN;

        listedItems[msg.sender][collectionContract] = tokenId;
        auctions[auctionCount] = _auction;
        auctionCount++;

        emit LogCreateAuction(msg.sender, collectionContract, tokenId, _auction.deadline);
    }

    /// @notice Create bid
    /// @param auctionId Auction ID of auction to bid on
    /// @param amount Amount to bid
    function bid(uint256 auctionId, uint256 amount) external bidRequirements(auctionId, amount) {
        Auction storage _auction = auctions[auctionId];
        _auction.highestBid = amount;
        _auction.highestBidder = msg.sender;
        bidders[msg.sender][auctionId] += amount;

        IERC20(_auction.currency).safeTransferFrom(msg.sender, address(this), amount);

        emit LogBid(msg.sender, _auction.highestBid, amount);
    }

    /// @notice Outbid currect highest bidder with 0.5 token
    /// @param auctionId Auction ID of auction to bid on
    function bidHalfTokenUp(uint256 auctionId) external {
        Auction storage _auction = auctions[auctionId];
        require(auctionId == _auction.auctionId, Errors.AuctionDoesNotExist());
        require(block.timestamp <= _auction.deadline, Errors.AuctionFinished(_auction.deadline));
        require(
            IERC20(_auction.currency).balanceOf(msg.sender) + bidders[msg.sender][auctionId]
                >= _auction.highestBid + HALF_TOKEN,
            Errors.InsufficientFunds(IERC20(_auction.currency).balanceOf(msg.sender))
        );

        uint256 amountToDeposit = (_auction.highestBid + HALF_TOKEN) - bidders[msg.sender][auctionId];
        bidders[msg.sender][auctionId] += amountToDeposit;
        _auction.highestBid += HALF_TOKEN;
        _auction.highestBidder = msg.sender;

        IERC20(_auction.currency).safeTransferFrom(msg.sender, address(this), amountToDeposit);

        emit LogBidHalfTokenUp(msg.sender, _auction.highestBid, amountToDeposit);
    }

    /// @notice Withdraw funds from auction
    /// @param auctionId Auction ID of closed auction
    /// @dev can call this function only after auction deadline, also charges fee for owner of smart contract
    function sellerWithdraw(uint256 auctionId) external {
        Auction storage _auction = auctions[auctionId];
        require(auctionId == _auction.auctionId, Errors.AuctionDoesNotExist());
        require(_auction.seller == msg.sender, Errors.NotOwnerOfAuction());
        require(
            _auction.highestBid >= _auction.reservePrice, Errors.PriceNotMet(_auction.reservePrice, _auction.highestBid)
        );
        require(block.timestamp > _auction.deadline, Errors.AuctionIsStillOpen(_auction.deadline));
        require(
            IERC721(_auction.collectionContract).ownerOf(_auction.tokenId) == _auction.highestBidder,
            Errors.NftNotSent(auctionId, _auction.highestBidder)
        );

        _auction.status = Status.CLOSED;
        uint256 feeAmount = (_auction.highestBid * FEE) / 10000;
        ownerAccumulatedFees[_auction.currency] += feeAmount;

        IERC20(_auction.currency).safeTransfer(msg.sender, _auction.highestBid - feeAmount);

        emit LogSellerWithdraw(msg.sender, _auction.highestBid - feeAmount, feeAmount);
    }

    /// @notice Users that did not won in auction can withdraw their funds back
    /// @param auctionId Auction ID of auction
    function bidderWithdraw(uint256 auctionId) external {
        Auction memory _auction = auctions[auctionId];
        require(auctionId == _auction.auctionId, Errors.AuctionDoesNotExist());
        require(
            _auction.highestBidder != msg.sender && _auction.reservePrice < _auction.highestBid,
            Errors.YouWonAuction(auctionId)
        );
        require(bidders[msg.sender][auctionId] > 0, Errors.NotPartOfAuction());

        IERC20(_auction.currency).safeTransfer(msg.sender, bidders[msg.sender][auctionId]);

        emit LogBidderWithdraw(msg.sender, bidders[msg.sender][auctionId]);
    }

    /// @notice Blacklists seller
    /// @param auctionId Auction ID of auction
    /// @dev blacklists if seller did not send NFT to bidder within 1 day after deadline or NFT changed owners while listed on Auction
    function blackListSeller(uint256 auctionId) external {
        Auction storage _auction = auctions[auctionId];
        require(msg.sender == _auction.highestBidder, Errors.CantBlackList());
        require(IERC721(_auction.collectionContract).ownerOf(_auction.tokenId) != msg.sender, Errors.YouAreTheOwner());

        if (
            block.timestamp >= _auction.deadline + 24 hours
                || IERC721(_auction.collectionContract).ownerOf(_auction.tokenId) != _auction.seller
        ) {
            blackList[_auction.seller] = true;
            blacklistedFor[_auction.seller] = auctionId;
            uint256 bidAmount = bidders[msg.sender][auctionId];
            _auction.status = Status.CLOSED;
            IERC20(_auction.currency).safeTransfer(msg.sender, bidAmount);

            emit LogBlackListSeller(msg.sender, _auction.seller, bidAmount);
        }
    }

    /// @notice Withdraw fees
    /// @param currency Currency of fees
    /// @param amount Amount to withdraw
    /// @dev Only owner can withdraw
    function withdrawFees(address currency, uint256 amount) external onlyOwner {
        require(ownerAccumulatedFees[currency] >= amount, Errors.InsufficientFunds(ownerAccumulatedFees[currency]));
        ownerAccumulatedFees[currency] -= amount;
        IERC20(currency).safeTransfer(msg.sender, amount);

        emit LogWithdrawFees(msg.sender, currency, amount);
    }

    function swapTokens() external {}

    /// @notice Get accumulated fees
    /// @param currency Currency of fees
    /// @dev Only owner can call function
    /// @return fees
    function getAccumulatedFees(address currency) external view onlyOwner returns (uint256) {
        return ownerAccumulatedFees[currency];
    }

    /// @notice Get Auction
    /// @param auctionId Auction ID of auction
    /// @return Auction state
    function getAuction(uint256 auctionId) external view returns (Auction memory) {
        return auctions[auctionId];
    }

    /// @notice Get all open Auctions
    /// @return openAuctions ID of open Auctions
    function getOpenAuctions() external view returns (uint256[] memory openAuctions) {
        uint256 _counter;
        for (uint256 i; i < auctionCount; ++i) {
            if (auctions[i].status == Status.OPEN) {
                openAuctions[_counter] = i;
                _counter++;
            }
        }
        return openAuctions;
    }

    /// @notice Get all currencies available to trade with
    /// @return addresses of all currencies
    function getAllowedCurrencies() external view returns (address[] memory) {
        address[] memory _currencies;
        for (uint256 i; i < allowedCurrencies.length; ++i) {
            _currencies[i] = allowedCurrencies[i];
        }
        return _currencies;
    }

    /// @notice Get auction where blacklisted
    /// @return blacklisted boolean
    /// @return auctionId auction ID
    function getBlacklistedFor() external view returns (bool blacklisted, uint256 auctionId) {
        (blacklisted, auctionId) = (blackList[msg.sender], blacklistedFor[msg.sender]);
    }
}
