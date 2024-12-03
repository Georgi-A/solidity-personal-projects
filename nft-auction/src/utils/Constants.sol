// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.8.28;

library Constants {
    /// the maximum days an item can be listed for
    uint256 public constant MAX_DURATION = 7;
    /// the minimum days an item can be listed for
    uint256 public constant MIN_DURATION = 1;
    /// used in 'bidOneTokenUp' function, allowing bidder to directly outbid by one token
    uint256 public constant ONE_TOKEN = 1;
    /// fee for sold NFT - 0.3%
    uint256 public constant FEE = 300;
}
