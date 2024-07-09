const { ethers } = require("hardhat");

async function main() {
  // Deploy Mock Chainlink Aggregator
  const MockV3Aggregator = await ethers.getContractFactory("MockV3Aggregator");
  const mockV3Aggregator = await MockV3Aggregator.deploy(3000 * 10 ** 8); // Initial price set to 3000

  await mockV3Aggregator.deployed();
  console.log("MockV3Aggregator deployed to:", mockV3Aggregator.address);

  // Deploy EthPriceBetting with the address of the mock aggregator
  const EthPriceBetting = await ethers.getContractFactory("EthPriceBetting");
  const ethPriceBetting = await EthPriceBetting.deploy(mockV3Aggregator.address);

  await ethPriceBetting.deployed();
  console.log("EthPriceBetting deployed to:", ethPriceBetting.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });