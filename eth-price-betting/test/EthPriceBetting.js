const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { chainlink, ethers } = require("hardhat");

describe("Eth Price Betting Contract", function () {

  beforeEach(async function () {

  
    // Deploy Mock Chainlink Aggregator
    const MockV3Aggregator = await ethers.getContractFactory("MockV3Aggregator");
    const mockAggregator = await MockV3Aggregator.deploy(3000 * 10 ** 8); // Initial price set to 3000

    [owner, addr1] = await ethers.getSigners();

    const EthContract = await ethers.getContractFactory("EthPriceBetting");
    contract = await EthContract.deploy(mockAggregator.target, "60");
  });

  describe("Deploy token", function () {
    it("Should deploy", async function () {

      const time = await contract.getEndTime();
      expect(await contract.getEndTime()).to.be.equal(time);
    });
  })

  describe("Create bet", function () {
    it("Should revert with higher amount statement", async function () {
      await expect(contract.connect(addr1).createBet("long")).to.be.revertedWith("Requires higher amount than 0.2 Ether");
    });

    it("Should revert with existing bet", async function () {
      const funds = ethers.parseEther("1");
      await contract.connect(addr1).createBet("long", {value: funds});
      await expect(contract.connect(addr1).createBet("long", {value: funds})).to.be.revertedWith("You have existing bet");
    });

    it("Should revert with Betting time finished", async function () {
      const funds = ethers.parseEther("1");
      await network.provider.send("evm_increaseTime", [3605]);
      await expect(contract.connect(addr1).createBet("long", {value: funds})).to.be.revertedWith("Betting time finished");
    });

    it("Should create bet and charge fee", async function () {
      const funds = ethers.parseEther("1");
            
      const fee = (BigInt(funds) * BigInt(200))/ BigInt(10000);
      const netBetAmount = funds - fee;
      const currentPrice = BigInt(3000);
      
      await expect(contract.connect(addr1).createBet("long", {value: funds}))
      .to.emit(contract, "BetCreated").withArgs(addr1, currentPrice, "long", netBetAmount);
      
      const addrBet = await contract.bets(addr1);

      expect(await addrBet.betAmount).to.be.equal(netBetAmount);
      
    });
  })

});
