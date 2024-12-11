const { expect } = require("chai");
const { ethers } = require("hardhat");
const { bigint } = require("hardhat/internal/core/params/argumentTypes");

describe("MultiSig Wallet Contract", function () {

  beforeEach(async function () {
    [participant1, participant2, participant3, participant4, participant5, attacker] = await ethers.getSigners();
    oneEth = BigInt(1_000_000_000_000_000_000);
    
    const MultiSigContract = await ethers.getContractFactory("MultiSigWallet");
    contract = await MultiSigContract.deploy([participant1, participant2, participant3, participant4, participant5], { value: ethers.parseEther("2")});
  });

  describe("Deploy contract", function () {
    it("Should deploy contract", async function () {
      const balance = oneEth + oneEth;
      expect(await contract.getBalance()).to.be.equal(balance);
    });
  })

  describe("Request withdraw", function () {
    it("Should revert for not being participant", async function () {
      await expect(contract.connect(attacker).requestWithdraw(oneEth)).to.be.revertedWith("You are not participant");
    });

    it("Should create request", async function () {
      await expect(contract.connect(participant2).requestWithdraw(oneEth)).to.be.fulfilled;
    });

    it("Should emit event on request", async function () {
      await expect(contract.connect(participant2).requestWithdraw(oneEth)).to.emit(contract, "Requested").withArgs(participant2, oneEth);
    });
  })

  describe("Cast Vote", function () {
    it("Should revert for not being participant", async function () {
      await expect(contract.connect(attacker).castVote(0,1)).to.be.revertedWith("You are not participant");
    });

    it("Should revert for casting vote twice", async function () {
      await contract.connect(participant2).requestWithdraw(oneEth);
      await contract.connect(participant1).castVote(0,1);
      await expect(contract.connect(participant1).castVote(0,0)).to.be.revertedWith("Already voted");
    });

    it("Should revert for closed voting period", async function () {
      await contract.connect(participant2).requestWithdraw(oneEth);
      await network.provider.send("evm_increaseTime", [86405]);
      await expect(contract.connect(participant1).castVote(0,1)).to.be.revertedWith("Voting closed");
    })

    it("Should cast vote", async function () {
      await contract.connect(participant2).requestWithdraw(oneEth);
      await expect(contract.connect(participant1).castVote(0,0)).to.be.fulfilled;
    })

    it("Should emit event on created vote", async function () {
      await contract.connect(participant2).requestWithdraw(oneEth);
      await expect(contract.connect(participant1).castVote(0,0)).to.emit(contract, "Voted").withArgs(0, participant1,0,0);
    })
  })

  describe("Change Vote", function () {
    it("Should revert for not being participant", async function () {
      await expect(contract.connect(attacker).changeVote(0)).to.be.revertedWith("Have not voted/Not participant");
    });

    it("Should revert without a vote", async function () {
      await contract.connect(participant2).requestWithdraw(oneEth);
      await expect(contract.connect(participant1).changeVote(0)).to.be.revertedWith("Have not voted/Not participant");
    });

    it("Should revert for closed voting period", async function () {
      await contract.connect(participant2).requestWithdraw(oneEth);
      await network.provider.send("evm_increaseTime", [86405]);
      await expect(contract.connect(participant1).castVote(0,1)).to.be.revertedWith("Voting closed");
    })

    it("Should change vote", async function () {
      await contract.connect(participant2).requestWithdraw(oneEth);
      await contract.connect(participant1).castVote(0,0);
      await expect(contract.connect(participant1).changeVote(0)).to.be.fulfilled;
    })

    it("Should emit event on changed vote", async function () {
      await contract.connect(participant2).requestWithdraw(oneEth);
      await contract.connect(participant1).castVote(0,0);
      await expect(contract.connect(participant1).changeVote(0)).to.emit(contract, "ChangeVote").withArgs(participant1,1);
    })
  })

  describe("Withdraw", function () {
    it("Should revert for not being the owner of request", async function () {
      await expect(contract.connect(attacker).withdraw(0)).to.be.revertedWith("Not owner of request");
    })

    it("Should revert for insufficient balance", async function () {
      await contract.connect(participant2).requestWithdraw(ethers.parseEther("3"));
      await contract.connect(participant1).castVote(0,0);
      await contract.connect(participant3).castVote(0,0);
      await contract.connect(participant4).castVote(0,0);
      await expect(contract.connect(attacker).withdraw(0)).to.be.revertedWith("Insufficient contract balance");
    });

    it("Should reject withdraw for rejected majority state", async function () {
      await contract.connect(participant2).requestWithdraw(oneEth);
      await contract.connect(participant1).castVote(0,1);
      await contract.connect(participant3).castVote(0,1);
      await contract.connect(participant4).castVote(0,1);
      await expect(contract.connect(participant2).withdraw(0)).to.be.revertedWith("Rejected or spent");
    });

    it("Should reject withdraw, already spent", async function () {
      await contract.connect(participant2).requestWithdraw(oneEth);

      await contract.connect(participant1).castVote(0,0);
      await contract.connect(participant3).castVote(0,0);
      await contract.connect(participant4).castVote(0,0);
      
      await network.provider.send("evm_increaseTime", [86405]);

      await contract.connect(participant2).withdraw(0);

      await expect(contract.connect(participant2).withdraw(0)).to.be.revertedWith("Rejected or spent");
    });

    it("Should withdraw", async function () {
      await contract.connect(participant2).requestWithdraw(oneEth);
      await contract.connect(participant1).castVote(0,0);
      await contract.connect(participant3).castVote(0,0);
      await contract.connect(participant4).castVote(0,0);
      
      await network.provider.send("evm_increaseTime", [86405]);

      await expect(contract.connect(participant2).withdraw(0)).to.be.fulfilled;
    });
  })
})