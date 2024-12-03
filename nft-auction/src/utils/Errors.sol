// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.8.28;

library Errors {
    /// @notice Thrown when user othan than owner calls function
    error OnlyOwner();
    /// @notice Thrown when duration is outside of allowed duration time
    error AuctionDurationOutOfBounds(uint256 minDuration, uint256 maxDuration);
    /// @notice Thrown when not owner of selected token
    error NotOwnerOfToken(address tokenOwner);
    /// @notice Thrown when item already listed
    error ItemAlreadyListed();
    /// @notice Thrown when price is not met
    error PriceNotMet(uint256 price, uint256 amount);
    /// @notice Thrown when 0 amount
    error ZeroInput();
    /// @notice Thrown when auction does not exist
    error AuctionDoesNotExist();
    /// @notice Thrown when auction has finished
    error AuctionFinished(uint256 deadline);
    /// @notice Thrown when insufficient funds
    error InsufficientFunds(uint256 balance);
    /// @notice Thrown when user is not owner of auction
    error NotOwnerOfAuction();
    /// @notice Thrown when auction is still open
    error AuctionIsStillOpen(uint256 deadline);
    /// @notice Thrown when NFT not sent to bidder
    error NftNotSent(uint256 auctionId, address bidder);
    /// @notice Thrown when bidder has won auction but tries to withdraw funds
    error YouWonAuction(uint256 auctionId);
    /// @notice Thrown when bidder has not participated to auction
    error NotPartOfAuction();
    /// @notice Thrown when bidder tries to blacklist seller
    error CantBlackList();
    /// @notice Thrown when bidder tries to blacklist, but has received their NFT
    error YouAreTheOwner();
    /// @notice Thrown when currency is not allowed
    error CurrencyNotAllowed();
    /// @notice Thrown when seller has been blacklisted
    error BlackListed(uint256 forAuctionId);

    error WonAuction(uint256 auctionId, address highestBidder, uint256 highestBid, uint256 reservePrice);
}
