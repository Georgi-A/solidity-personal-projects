require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");

const { vars } = require("hardhat/config");

const ALCHEMY_API_KEY = vars.get("ALCHEMY_API_KEY");
const SEPOLIA_PRIVATE_KEY = vars.get("SEPOLIA_PRIVATE_KEY");
const ETHERSCAN_PRIVATE_KEY = vars.get("ETHERSCAN_PRIVATE_KEY");

module.exports = {
  solidity: "0.8.19",
  networks: {
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      accounts: [SEPOLIA_PRIVATE_KEY]
    },
    forking: {
      url: `https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
    }
  },
  etherscan: {
    apiKey: ETHERSCAN_PRIVATE_KEY
  },
  sourcify: {
    enabled: true
  }
};