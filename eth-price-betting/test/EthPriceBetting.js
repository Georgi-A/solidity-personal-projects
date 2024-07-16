const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Eth Price Betting Contract", function () {

  beforeEach(async function () {

  
    // Deploy Mock Chainlink Aggregator
    const MockV3Aggregator = await ethers.getContractFactory("MockV3Aggregator");
    mockAggregator = await MockV3Aggregator.deploy(3000 * 10 ** 8); // Initial price set to 3000

    [owner, addr1] = await ethers.getSigners();
    funds = ethers.parseEther("1");

    const EthContract = await ethers.getContractFactory("EthPriceBetting");
    contract = await EthContract.deploy(mockAggregator.target, "60", { value: ethers.parseEther("2")});
  });

  describe("Deploy betting contract and mockAggregator", function () {
    it("Should deploy both contracts", async function () {
      const time = await contract.getEndTime();

      expect(await contract.getEndTime()).to.be.equal(time);
      expect(await mockAggregator.getAnswer()).to.be.equal(3000);
    });
  })

  describe("Create bet", function () {
    it("Should revert with higher amount statement", async function () {
      await expect(contract.connect(addr1).createBet("long")).to.be.revertedWith("Requires higher amount than 0.2 Ether");
    });

    it("Should revert with existing bet", async function () {
      await contract.connect(addr1).createBet("long", {value: funds});
      await expect(contract.connect(addr1).createBet("long", {value: funds})).to.be.revertedWith("You have existing bet");
    });

    it("Should revert with Betting time finished", async function () {
      await network.provider.send("evm_increaseTime", [3605]);
      await expect(contract.connect(addr1).createBet("long", {value: funds})).to.be.revertedWith("Betting time finished");
    });

    it("Should create bet and charge fee", async function () {
      const fee = (BigInt(funds) * BigInt(200))/ BigInt(10000);
      const netBetAmount = funds - fee;
      const currentPrice = BigInt(3000);
      
      await expect(contract.connect(addr1).createBet("long", {value: funds}))
      .to.emit(contract, "BetCreated").withArgs(addr1, currentPrice, "long", netBetAmount);
      
      const addrBet = await contract.bets(addr1);

      expect(await addrBet.betAmount).to.be.equal(netBetAmount);
      
    });
  })

  describe("Settle bet", function () {
    it("Should revert for settling early", async function () {
      await expect(contract.connect(addr1).settleBet()).to.be.revertedWith("Betting time not finished");
    });

    it("Should revert for non participants", async function () {
      await network.provider.send("evm_increaseTime", [3605]);

      await expect(contract.connect(addr1).settleBet()).to.be.revertedWith("You have not participated");
    });

    it("Should revert without updated price", async function () {
      await contract.connect(addr1).createBet("long", {value: funds});
      await network.provider.send("evm_increaseTime", [3605]);
      await mockAggregator.setAnswer(0);
      
      await expect(contract.connect(addr1).settleBet()).to.be.revertedWith("Eth price cant be 0");
    });

    it("Should revert for low contract balance", async function () {
      funds = ethers.parseEther("2");
      await contract.connect(addr1).createBet("long", {value: funds});
      await network.provider.send("evm_increaseTime", [3605]);
      await mockAggregator.setAnswer(3005);
      console.log(await mockAggregator.getAnswer());
      
      await expect(contract.connect(addr1).settleBet()).to.be.revertedWith("Not enough funds, come back later");
    });
  })

});
