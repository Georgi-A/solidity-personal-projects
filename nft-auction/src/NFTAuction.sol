// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.8.28;

// Auction dependencies
import {Errors} from "src/utils/Errors.sol";
import {Constants} from "src/utils/Constants.sol";

// Openzeppelin dependecies
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Uniswap dependencies
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

/// @title English Auction for NFTs
/// @notice This smart contract allows users to sell and bid on NFTs. Owner receives 0.3% for each sold NFT.
/// @dev The smart contract does not hold ERC721 tokens. Instead, expects seller to send NFT to highest bidder within 1 day after the auction has finished.
/// In case seller does not send the NFT to the buyer or NFT has changed owner outside auction, seller will be blacklisted and will not be allowed to sell anymore,
/// while buyer/bidder will receive refund for that auction. Payments are done with ERC20 tokens, seller can select from allowed currencies. Also bidders can swap tokens within smart contract.
/// 'swapTokens' function uses Chainlink Oracle integration.
contract NFTAuction {
    using SafeERC20 for IERC20;

    //////////////////////////////////////////////////
    ////                EVENTS                    ////
    //////////////////////////////////////////////////

    event LogCreateAuction(
        address indexed seller, address indexed collectionContract, uint256 indexed tokenId, uint256 deadline
    );
    event LogCreateBid(address indexed bidder, uint256 indexed auctionId, uint256 amount);
    event LogBidOneTokenUp(address indexed bidder, uint256 indexed auctionId, uint256 amount);
    event LogSellerWithdraw(address indexed seller, uint256 amount, uint256 feeAmount);
    event LogBidderWithdraw(address indexed bidder, uint256 refund);
    event LogBlackListSeller(address indexed bidder, address indexed seller, uint256 refund);
    event LogWithdrawFees(address indexed owner, address indexed currency, uint256 amount);
    event LogRelistItem(uint256 auctionId, uint256 deadline, uint256 reservePrice);

    //////////////////////////////////////////////////
    ////                 ENUMS                    ////
    //////////////////////////////////////////////////

    /// @notice Status of auction
    enum Status {
        OPEN,
        CLOSED
    }

    //////////////////////////////////////////////////
    ////                 STRUCTS                  ////
    //////////////////////////////////////////////////

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

    //////////////////////////////////////////////////
    ////                VARIABLES                 ////
    //////////////////////////////////////////////////

    /// Owner of smart contract
    address public immutable owner;
    /// Uniswap router address
    ISwapRouter public immutable swapRouter;

    /// Total auctions count
    uint256 public auctionCount;
    /// Supported currencies to trade with
    address[] private supportedCurrencies;
    /// Records blacklisted sellers
    mapping(address seller => bool) private blackList;
    /// Auction where seller was blacklisted
    mapping(address seller => uint256 actionId) private blacklistedFor;
    /// Auction state
    mapping(uint256 auctionId => Auction) private auctions;
    /// Records bidder current bid amounts
    mapping(address bidder => mapping(uint256 auctionId => uint256 amount)) private bidders;
    /// Records seller listed items
    mapping(uint256 tokenId => mapping(address contractAddress => address seller)) private listedItem;
    /// Records the accumulated fees of owner
    mapping(address tokenAddress => uint256 feeAmount) private ownerAccumulatedFees;

    constructor(ISwapRouter _swapRouter, IERC20[] memory _supportedCurrencies) {
        owner = msg.sender;
        swapRouter = _swapRouter;

        // Feed in allowed currencies
        for (uint256 i; i < _supportedCurrencies.length; i++) {
            supportedCurrencies.push(address(_supportedCurrencies[i]));
        }
    }

    //////////////////////////////////////////////////
    ////                 MODIFIERS                ////
    //////////////////////////////////////////////////

    modifier onlyOwner() {
        require(msg.sender == owner, Errors.OnlyOwner());
        _;
    }

    modifier existingAuction(uint256 auctionId) {
        require(auctionId <= auctionCount, Errors.AuctionDoesNotExist());
        _;
    }

    modifier auctionRequirements(
        address collectionContract,
        uint256 tokenId,
        uint256 duration,
        address currency,
        uint256 reservePrice
    ) {
        require(
            duration >= Constants.MIN_DURATION && duration <= Constants.MAX_DURATION,
            Errors.AuctionDurationOutOfBounds(Constants.MIN_DURATION, Constants.MAX_DURATION)
        );
        require(
            IERC721(collectionContract).ownerOf(tokenId) == msg.sender,
            Errors.NotOwnerOfToken(IERC721(collectionContract).ownerOf(tokenId))
        );
        require(listedItem[tokenId][collectionContract] != msg.sender, Errors.ItemAlreadyListed());
        require(reservePrice > 0, Errors.ZeroInput());
        require(_getCurrency(currency), Errors.CurrencyNotSupported());
        require(!blackList[msg.sender], Errors.BlackListed(blacklistedFor[msg.sender]));
        _;
    }

    modifier bidRequirements(uint256 auctionId, uint256 amount) {
        Auction memory _auction = auctions[auctionId];
        require(amount > 0, Errors.ZeroInput());
        require(amount > _auction.highestBid, Errors.PriceNotMet(_auction.highestBid, amount));
        require(
            IERC20(_auction.currency).balanceOf(msg.sender) >= amount,
            Errors.InsufficientFunds(IERC20(_auction.currency).balanceOf(msg.sender))
        );
        require(block.timestamp <= _auction.deadline, Errors.AuctionFinished(_auction.deadline));
        _;
    }

    //////////////////////////////////////////////////
    ////             EXTERNAL FUNCS               ////
    //////////////////////////////////////////////////

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
    ) external auctionRequirements(collectionContract, tokenId, duration, currency, reservePrice) {
        Auction memory _auction;
        _auction.auctionId = ++auctionCount;
        _auction.collectionContract = collectionContract;
        _auction.tokenId = tokenId;
        _auction.seller = msg.sender;
        _auction.deadline = block.timestamp + (duration * 1 days);
        _auction.currency = currency;
        _auction.reservePrice = reservePrice;
        _auction.status = Status.OPEN;

        listedItem[tokenId][collectionContract] = msg.sender;
        auctions[auctionCount] = _auction;

        emit LogCreateAuction(msg.sender, collectionContract, tokenId, _auction.deadline);
    }

    /// @notice Create bid
    /// @param auctionId Auction ID of auction to bid on
    /// @param amount Amount to bid
    function createBid(uint256 auctionId, uint256 amount) external existingAuction(auctionId) bidRequirements(auctionId, amount)  {
        Auction storage _auction = auctions[auctionId];
        _auction.highestBid = amount;
        _auction.highestBidder = msg.sender;
        bidders[msg.sender][auctionId] += amount;

        IERC20(_auction.currency).safeTransferFrom(msg.sender, address(this), amount);

        emit LogCreateBid(msg.sender, auctionId, amount);
    }

    /// @notice Outbid currect highest bidder with 1 token
    /// @param auctionId Auction ID of auction to bid on
    function bidOneTokenUp(uint256 auctionId) external existingAuction(auctionId) {
        Auction storage _auction = auctions[auctionId];
        require(block.timestamp <= _auction.deadline, Errors.AuctionFinished(_auction.deadline));
        require(
            IERC20(_auction.currency).balanceOf(msg.sender) + bidders[msg.sender][auctionId]
                >= _auction.highestBid + Constants.ONE_TOKEN,
            Errors.InsufficientFunds(IERC20(_auction.currency).balanceOf(msg.sender))
        );

        uint256 amountToDeposit = (_auction.highestBid + Constants.ONE_TOKEN) - bidders[msg.sender][auctionId];
        bidders[msg.sender][auctionId] += amountToDeposit;
        _auction.highestBid += Constants.ONE_TOKEN;
        _auction.highestBidder = msg.sender;

        IERC20(_auction.currency).safeTransferFrom(msg.sender, address(this), amountToDeposit);

        emit LogBidOneTokenUp(msg.sender, _auction.auctionId, amountToDeposit);
    }

    /// @notice Withdraw funds from auction
    /// @param auctionId Auction ID of closed auction
    /// @dev seller can withdraw only after auction deadline and nft has been sent to bidder, also charges fee for owner of smart contract
    function sellerWithdraw(uint256 auctionId) external existingAuction(auctionId) {
        Auction storage _auction = auctions[auctionId];
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
        listedItem[_auction.tokenId][_auction.collectionContract] = address(0);
        uint256 feeAmount = (_auction.highestBid * Constants.FEE) / 10000;
        ownerAccumulatedFees[_auction.currency] += feeAmount;

        IERC20(_auction.currency).safeTransfer(msg.sender, _auction.highestBid - feeAmount);

        emit LogSellerWithdraw(msg.sender, _auction.highestBid - feeAmount, feeAmount);
    }

    function reListItem(uint256 auctionId, uint256 duration, uint256 reservePrice) external existingAuction(auctionId) {
        Auction storage _auction = auctions[auctionId];
        require(
            duration >= Constants.MIN_DURATION && duration <= Constants.MAX_DURATION,
            Errors.AuctionDurationOutOfBounds(Constants.MIN_DURATION, Constants.MAX_DURATION)
        );
        require(_auction.seller == msg.sender, Errors.NotOwnerOfAuction());
        require(
            _auction.highestBid <= _auction.reservePrice,
            Errors.WonAuction(_auction.auctionId, _auction.highestBidder, _auction.highestBid, _auction.reservePrice)
        );
        require(block.timestamp > _auction.deadline, Errors.AuctionIsStillOpen(_auction.deadline));

        _auction.status = Status.OPEN;
        _auction.deadline = block.timestamp + (duration * 1 days);
        _auction.highestBid = 0;
        _auction.highestBidder = address(0);
        _auction.reservePrice = reservePrice;

        emit LogRelistItem(_auction.auctionId, _auction.deadline, reservePrice);
    }

    /// @notice Users that did not won in auction can withdraw their funds back
    /// @param auctionId Auction ID of auction
    function bidderWithdraw(uint256 auctionId) external existingAuction(auctionId) {
        Auction memory _auction = auctions[auctionId];
        require(bidders[msg.sender][auctionId] > 0, Errors.NotPartOfAuction());

        if(_auction.highestBidder == msg.sender &&  _auction.highestBid > _auction.reservePrice) {
            revert Errors.YouAreTheWinner(auctionId);
        }else {
            IERC20(_auction.currency).safeTransfer(msg.sender, bidders[msg.sender][auctionId]);
            emit LogBidderWithdraw(msg.sender, bidders[msg.sender][auctionId]);
        }
    }

    /// @notice Blacklists seller
    /// @param auctionId Auction ID of auction
    /// @dev blacklists if seller did not send NFT to bidder within 1 day after deadline or NFT changed owners while listed on Auction
    function blackListSeller(uint256 auctionId) external existingAuction(auctionId) {
        Auction storage _auction = auctions[auctionId];
        require(
            msg.sender == _auction.highestBidder && _auction.reservePrice <= _auction.highestBid, Errors.CantBlackList()
        );
        require(IERC721(_auction.collectionContract).ownerOf(_auction.tokenId) != msg.sender, Errors.YouAreTheOwner());

        if (
            block.timestamp > _auction.deadline + 1 days
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
        require(_getCurrency(currency), Errors.CurrencyNotSupported());

        ownerAccumulatedFees[currency] -= amount;
        IERC20(currency).safeTransfer(msg.sender, amount);

        emit LogWithdrawFees(msg.sender, currency, amount);
    }

    /// @notice Add currency
    /// @param currency new currency address
    /// @dev Only owner can add currency
    function addCurrency(address currency) external onlyOwner {
        require(currency != address(0), Errors.ZeroInput());
        supportedCurrencies.push(currency);
    }

    function swapTokens(address tokenIn, address tokenOut, uint256 amountOut, uint256 amountInMaximum, uint256 deadlineMinutes) external returns (uint256 amountIn) {
        require(amountInMaximum > 0, Errors.ZeroInput());
        require(deadlineMinutes > 0, Errors.ZeroInput());
        require(tokenIn != address(0) && tokenOut != address(0), Errors.ZeroInput());

        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountInMaximum);
        TransferHelper.safeApprove(tokenIn, address(swapRouter), amountInMaximum);

        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: 3000,
            recipient: msg.sender,
            deadline: block.timestamp + 60 * deadlineMinutes,
            amountOut: amountOut,
            amountInMaximum: amountInMaximum,
            sqrtPriceLimitX96: 0
        });

        amountIn = swapRouter.exactOutputSingle(params);

        if (amountIn < amountInMaximum) {
            TransferHelper.safeApprove(tokenIn, address(swapRouter), 0);
            TransferHelper.safeTransfer(tokenIn, msg.sender, amountInMaximum - amountIn);
        }

    }

    //////////////////////////////////////////////////
    ////             GETTER FUNCS                 ////
    //////////////////////////////////////////////////

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
        uint256 openAuctionCount;

        for (uint256 i = 1; i <= auctionCount; i++) {
            if (auctions[i].status == Status.OPEN) {
                openAuctionCount++;
            }
        }
        openAuctions = new uint256[](openAuctionCount);
        uint256 _counter;

        for (uint256 i = 1; i <= auctionCount; i++) {
            if (auctions[i].status == Status.OPEN) {
                openAuctions[_counter] = i;
                _counter++;
            }
        }

        return openAuctions;
    }

    /// @notice Get all currencies available to trade with
    /// @return addresses of all currencies
    function getSupportedCurrencies() external view returns (address[] memory) {
        address[] memory _currencies = new address[](supportedCurrencies.length);
        for (uint256 i = 0; i < supportedCurrencies.length; ++i) {
            _currencies[i] = supportedCurrencies[i];
        }
        return _currencies;
    }

    /// @notice Get auction where blacklisted
    /// @return blacklisted boolean
    /// @return auctionId auction ID
    function getBlackListedFor() external view returns (bool blacklisted, uint256 auctionId) {
        (blacklisted, auctionId) = (blackList[msg.sender], blacklistedFor[msg.sender]);
    }

    //////////////////////////////////////////////////
    ////             INTERNAL FUNCS               ////
    //////////////////////////////////////////////////

    /// @notice Check on supported currency
    /// @param currency selected currency
    /// @return bool return if currency is supported
    function _getCurrency(address currency) internal view returns (bool) {
        for (uint256 i = 0; i < supportedCurrencies.length; ++i) {
            if (currency == supportedCurrencies[i]) {
                return true;
            }
        }
        return false;
    }

    function _retrySwap() internal {

    }
}
