// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

contract EthPriceBetting is AutomationCompatibleInterface {
    // Structure representing a bet with amount, ETH price at the time of placing the bet, position (long/short), and participation status
    struct Bet {
        uint256 betAmount;
        uint256 priceAtPlacedBet;
        string position;
        bool participated;
    }

    // Immutable data feed interface for Chainlink price feed
    AggregatorV3Interface internal immutable dataFeed;

    // Immutable address for the contract admin
    address private immutable admin;

    // Address for the forwarder authorized to perform certain actions
    address private forwarderAddr;

    // Fee constant for placing bets (2%)
    uint256 public constant FEE = 200;

    // Variables to store the ETH price at the end of betting and the times for betting opening and closing
    uint256 public closingBetEthPrice;
    uint256 public closingBetTime;
    uint256 public openBetTime;

    // Mapping to store bets placed by participants
    mapping(address => Bet) public bets;

    // Events to log bet creation and bet settlement
    event BetCreated(
        address indexed participant,
        uint256 indexed priceAgainst,
        string indexed position,
        uint256 amount
    );
    event Settled(
        address indexed participant,
        uint256 indexed payout,
        uint256 indexed priceAgainst
    );

    // Constructor to initialize the contract with the betting duration and setting initial values
    constructor(address _dataFeed, uint256 _bettingDurationMinutes) payable {
        admin = msg.sender;
        dataFeed = AggregatorV3Interface(_dataFeed);
        openBetTime = block.timestamp;
        closingBetTime = openBetTime + (_bettingDurationMinutes * 1 minutes);
    }

    // Modifier to restrict access to admin-only functions
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not the owner");
        _;
    }

    // Modifier to restrict access to forwarder-only functions
    modifier onlyForwarder(address _forwarderAddr) {
        require(_forwarderAddr == forwarderAddr, "Not allowed");
        _;
    }

    // Fallback function to receive Ether
    receive() external payable {}

    // Function to create a new bet with a specified position (long/short)
    function createBet(string memory _position) external payable {
        uint256 currentTime = block.timestamp;

        require(
            msg.value >= 0.2 ether,
            "Requires higher amount than 0.2 Ether"
        );
        require(
            bets[msg.sender].participated == false,
            "You have existing bet"
        );
        require(msg.sender == tx.origin, "Only EOA can participate");
        require(currentTime <= closingBetTime, "Betting time finished");

        uint256 calculatedFee = (msg.value * FEE) / 10000;
        uint256 netBetAmount = msg.value - calculatedFee;

        uint256 currentPrice = uint256(getChainlinkDataFeedLatestAnswer());

        bets[msg.sender] = Bet(netBetAmount, currentPrice, _position, true);

        emit BetCreated(msg.sender, currentPrice, _position, netBetAmount);
    }

    // Function to settle a bet, determining the outcome and transferring the winnings if applicable
    function settleBet() external {
        Bet memory addressBet = bets[msg.sender];

        require(block.timestamp > closingBetTime, "Betting time not finished");
        require(addressBet.participated == true, "You have not participated");
        require(closingBetEthPrice != 0, "Eth price cant be 0");

        bytes32 hashedPosition = keccak256(
            abi.encodePacked(addressBet.position)
        );

        bytes32 hashedLong = keccak256(abi.encodePacked("long"));
        bytes32 hashedShort = keccak256(abi.encodePacked("short"));

        bool isWinningBet = (hashedPosition == hashedLong &&
            addressBet.priceAtPlacedBet >= closingBetEthPrice) ||
            (hashedPosition == hashedShort &&
                addressBet.priceAtPlacedBet <= closingBetEthPrice);

        uint payoutAmount = isWinningBet ? addressBet.betAmount * 2 : 0;

        require(
            address(this).balance >= payoutAmount,
            "Not enough funds, come back later"
        );

        delete bets[msg.sender];

        (bool sent, ) = msg.sender.call{value: payoutAmount}("");
        require(sent, "Transaction failed");

        emit Settled(msg.sender, payoutAmount, closingBetEthPrice);
    }

    // Function for the admin to withdraw all Ether from the contract
    function withdraw() external onlyAdmin {
        require(address(this).balance > 0, "No available funds");
        (bool sent, ) = msg.sender.call{value: address(this).balance}("");
        require(sent, "Transaction failed");
    }

    // Function for the admin to open a new betting period with a specified end time
    function openNewBettingPeriod(uint256 newEndTime) external onlyAdmin {
        openBetTime = block.timestamp;
        closingBetTime = newEndTime;
        closingBetEthPrice = 0;
    }

    // Function to set the forwarder address
    function setForwarder(address _forwarderAddr) external onlyAdmin {
        require(_forwarderAddr != address(0), "Cant be address 0");
        forwarderAddr = _forwarderAddr;
    }

    // Function to get the closing bet time
    function getEndTime() external view returns (uint256) {
        return closingBetTime;
    }

    // Function to get the latest price from the Chainlink data feed
    function getChainlinkDataFeedLatestAnswer() public view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundID */,
            int answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        return answer / 1e8;
    }

    // Function to check if upkeep is needed for Chainlink Automation
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        upkeepNeeded =
            block.timestamp >= closingBetTime &&
            closingBetEthPrice == 0;
    }

    // Function to perform upkeep for Chainlink Automation, setting the closing ETH price
    function performUpkeep(
        bytes calldata /* performData */
    ) external override onlyForwarder(msg.sender) {
        if (block.timestamp >= closingBetTime && closingBetEthPrice == 0) {
            closingBetEthPrice = uint256(getChainlinkDataFeedLatestAnswer());
        }
    }
}
