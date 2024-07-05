# Eth Price Betting DApp

## Overview

Eth Price Betting is a decentralized application (DApp) built on Ethereum that allows users to place bets on the price of Ether (ETH) at a future time. Users can place either "long" or "short" bets, depending on whether they believe the price of ETH will go up or down. The contract uses Chainlink's price feed to get the current price of ETH and settle bets.

## Features

- Users can place bets on the future price of ETH.
- Bets can be "long" (price will go up) or "short" (price will go down).
- Admin functions to manage the betting periods and withdraw funds.
- Uses Chainlink for reliable price data.
- Simple and intuitive UI built with React.

## Prerequisites

- Node.js and npm
- MetaMask or any other Web3 provider
- Ethereum network (Mainnet or Testnet)

## Getting Started

### 1. Clone the Repository
### 2. Install Dependencies

```bash
npm install
```

### 3. Configure Environment

Update the smart contract address and owner address in the `App.js` file.

```javascript
const EthPriceBettingAddress = '0xYourContractAddress';
const ownerAddress = '0xYourOwnerAddress';
```

### 4. Compile and Deploy Smart Contract

If you need to deploy the smart contract yourself, follow these steps:

1. Install Hardhat.
2. Configure your deployment script.
3. Deploy the contract to your desired Ethereum network.
  
### 7. Run the Application

In front-end directory:

```bash
npm start
```

### 6. Register with ChainLink Automations

To use ChainLink Automations for this DApp, follow these steps:

1. **Register Custom Logic Automation on ChainLink Automation:**
   - Go to the ChainLink Automation platform and register your custom logic automation.
   - Provide the necessary details such as contract address.

2. **Set Forwarder Address:**
   - After registering, you will receive a forwarder address from ChainLink.
   - Use the `setForwarder` function in your smart contract to set this forwarder address.
   - You can do this via a direct transaction from your wallet or through the DApp interface by entering the forwarder address and clicking the "Set Forwarder Address" button.

## Smart Contract

The smart contract is located in the `contracts` directory. It handles the core logic for placing and settling bets, managing the betting period, and interacting with the Chainlink price feed.

### Key Functions

- `createBet`: Allows users to place a new bet.
- `settleBet`: Settles a user's bet and transfers winnings if applicable.
- `withdraw`: Allows the admin to withdraw funds from the contract.
- `openNewBettingPeriod`: Opens a new betting period with a specified end time.
- `setForwarder`: Sets the forwarder address for automation purposes.
- `getEndTime`: Returns the current end time of the betting period.
- `getChainlinkDataFeedLatestAnswer`: Retrieves the latest ETH price from Chainlink.

## Frontend

The frontend is built with React and utilizes ethers.js for interacting with the Ethereum blockchain.

### Components

- `App.js`: Main component that handles state and renders the UI.
- `ABI.js`: Contains the ABI for the deployed smart contract.

### Key Functions

- `initializeEthers`: Initializes the ethers provider, signer, and contract.
- `createBet`: Places a new bet.
- `settleBet`: Settles a user's bet.
- `withdraw`: Admin function to withdraw funds.
- `openNewBettingPeriod`: Admin function to open a new betting period.
- `getCurrentPrice`: Retrieves the current ETH price.
- `setForwarderAddress`: Sets the forwarder address.
- `getEndTime`: Retrieves the end time of the current betting period.

## Usage

1. Connect your MetaMask wallet.
2. Place a bet by entering the position (long/short) and the bet amount.
3. Wait for the betting period to end.
4. Settle your bet to see if you won.
5. Admins can open new betting periods and withdraw funds from the contract.
