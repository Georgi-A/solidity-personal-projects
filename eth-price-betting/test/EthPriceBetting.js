const { expect } = require("chai");
const { ethers } = require("hardhat");
const { bigint } = require("hardhat/internal/core/params/argumentTypes");

describe("Eth Price Betting Contract", function () {

  beforeEach(async function () {

  
    // Deploy Mock Chainlink Aggregator
    const MockV3Aggregator = await ethers.getContractFactory("MockV3Aggregator");
    mockAggregator = await MockV3Aggregator.deploy(3000 * 10 ** 8); // Initial price set to 3000

    [owner, addr1, forwarder] = await ethers.getSigners();
    funds = ethers.parseEther("1");

    const EthContract = await ethers.getContractFactory("EthPriceBetting");
    contract = await EthContract.deploy(mockAggregator.target, "60", { value: ethers.parseEther("1")});
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
      funds = ethers.parseEther("3");
      await contract.setForwarder(forwarder.address);
      await mockAggregator.setAnswer(3005);
      await contract.connect(addr1).createBet("long", {value: funds});
      await network.provider.send("evm_increaseTime", [3605]);
      await contract.connect(forwarder).performUpkeep("0x");

      await expect(contract.connect(addr1).settleBet()).to.be.revertedWith("Not enough funds, come back later");
    });

    it("Should revert for settling twice", async function () {
      await contract.setForwarder(forwarder.address);
      await mockAggregator.setAnswer(2990);
      await contract.connect(addr1).createBet("short", {value: funds});
      await network.provider.send("evm_increaseTime", [3605]);
      await contract.connect(forwarder).performUpkeep("0x");
      await contract.connect(addr1).settleBet();

      await expect(contract.connect(addr1).settleBet()).to.be.revertedWith("You have not participated");;
    });

    it("Should receive winning funds for long position and emit", async function () {
      await contract.setForwarder(forwarder.address);
      await mockAggregator.setAnswer(3005);
      await contract.connect(addr1).createBet("long", {value: funds});
      await network.provider.send("evm_increaseTime", [3605]);
      await contract.connect(forwarder).performUpkeep("0x");

      const closingBetPrice = BigInt(3005);
      const fee = (BigInt(funds) * BigInt(200))/ BigInt(10000);
      const payoutAmount = (funds - fee) * BigInt(2);

      await expect(contract.connect(addr1).settleBet())
      .to.emit(contract, "Settled").withArgs(addr1, payoutAmount, closingBetPrice).and.to.be.fulfilled;
    });

    it("Should receive winning funds for short position and emit", async function () {
      await contract.setForwarder(forwarder.address);
      await mockAggregator.setAnswer(2990);
      await contract.connect(addr1).createBet("short", {value: funds});
      await network.provider.send("evm_increaseTime", [3605]);
      await contract.connect(forwarder).performUpkeep("0x");

      const closingBetPrice = BigInt(2990);
      const fee = (BigInt(funds) * BigInt(200))/ BigInt(10000);
      const payoutAmount = (funds - fee) * BigInt(2);

      await expect(contract.connect(addr1).settleBet())
      .to.emit(contract, "Settled").withArgs(addr1, payoutAmount, closingBetPrice).and.to.be.fulfilled;
    });

    it("Should not receive funds", async function () {
      await contract.setForwarder(forwarder.address);
      await mockAggregator.setAnswer(3000);
      await contract.connect(addr1).createBet("long", {value: funds});
      await mockAggregator.setAnswer(2990);
      await network.provider.send("evm_increaseTime", [3605]);
      await contract.connect(forwarder).performUpkeep("0x");
      const closingBetPrice = BigInt(2990);
      const payoutAmount = BigInt(0);

      await expect(contract.connect(addr1).settleBet())
        .to.emit(contract, "Settled").withArgs(addr1.address, payoutAmount, closingBetPrice);
    });
  })

  describe("Withdraw contract balance", function () {
    it("Should revert with not admin", async function () {
      await expect(contract.connect(addr1).withdraw()).to.be.revertedWith("Only admin can execute");
    });

    it("Should withdraw", async function () {
      await expect(contract.connect(owner).withdraw()).to.be.fulfilled;
    });
  })

  describe("Open new bet", function () {
    it("Should revert with not admin", async function () {
      await expect(contract.connect(addr1).openNewBettingPeriod(1229992)).to.be.revertedWith("Only admin can execute");
    });

    it("Should revert for betting period not finished", async function () {
      await expect(contract.connect(owner).openNewBettingPeriod(1229992)).to.be.revertedWith("Betting period not finished");
    });

    it("Should set new opening time", async function () {
      await network.provider.send("evm_increaseTime", [3605]);
      const newTime = 1721185417;
      await contract.connect(owner).openNewBettingPeriod(newTime);
      expect(await contract.connect(addr1).getEndTime()).to.be.equal(newTime);
    });
  })

  describe("Set forwarder", function () {
    it("Should revert with not admin", async function () {
      await expect(contract.connect(addr1).setForwarder(owner.address)).to.be.revertedWith("Only admin can execute");
    });

    it("Should revert for setting address(0)", async function () {
      await expect(contract.setForwarder(ethers.ZeroAddress)).to.be.revertedWith("Cant be address 0");
    });

    it("Should set forwarder address", async function () {
      await expect(contract.setForwarder(forwarder)).to.be.fulfilled;
    });
  })
});
