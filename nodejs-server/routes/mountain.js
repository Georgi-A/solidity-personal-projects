const express = require("express");
const fs = require("fs");
const { ethers, WebSocketProvider } = require("ethers");

const router = express.Router();

const provider = new WebSocketProvider(
  "wss://eth-mainnet.g.alchemy.com/v2/Ap2B9dlVZwl3n93PVT-r-oVrpG2XRCsR");

const CONTRACT_ADDRESS = "0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C";
const ABI = [
  "function rewardMultiplier() view returns (uint256)",
  "function totalSupply() view returns (uint256)"
];

const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, provider);

const START_TIMESTAMP = 1737109200;

router.get("/mountain", async (req, res) => {
  try {
    const latestBlockNum = await provider.getBlockNumber();
    const latestBlock = await provider.getBlock(latestBlockNum);
    const latestBlockTs = latestBlock.timestamp;

    if (START_TIMESTAMP > latestBlockTs) {
      return res.json({
        message: "No data",
        days: 0
      });
    }

    const dailyData = [];
    let previousMultiplier = null;

    let dayTimestamp = START_TIMESTAMP;

    while (dayTimestamp <= latestBlockTs) {
      const foundBlock = await findBlockOnOrAfter(dayTimestamp, 0, latestBlockNum);
      if (foundBlock == null) {
        break;
      }

      const blockInfo = await provider.getBlock(foundBlock);
      const rewardMultiplier = await contract.rewardMultiplier({ blockTag: foundBlock });

      const totalSupply = await contract.totalSupply({ blockTag: foundBlock });

      let dailyApy = 0;
      if (previousMultiplier) {
        const ratio = Number(rewardMultiplier) / Number(previousMultiplier);
        dailyApy = Number(totalSupply) * (ratio - 1) * 100; 
      }

      const dailyApyStr = BigInt(dailyApy).toString();

      const date = new Date(blockInfo.timestamp * 1000);

      dailyData.push({    
        blockNumber: foundBlock,
        totalAssets: totalSupply.toString(),
        date: date.toLocaleString(),
        apy: dailyApyStr,
      });

      previousMultiplier = rewardMultiplier;
      dayTimestamp += 86400;
    }

    fs.writeFileSync("mountain.json", JSON.stringify(dailyData, null, 2));

    return res.json({
      message: "Success",
      days: dailyData.length
    });
  } catch (error) {
    console.error("Error computing daily APY until today:", error);
    return res.status(500).json({ error: error.message });
  }
});

async function findBlockOnOrAfter(targetTs, lowBlock, highBlock) {
  let candidate = null;
  while (lowBlock <= highBlock) {
    const mid = Math.floor((lowBlock + highBlock) / 2);
    const block = await provider.getBlock(mid);
    if (!block) break; 

    if (block.timestamp === targetTs) {
      return mid;
    } else if (block.timestamp < targetTs) {
      lowBlock = mid + 1;
    } else {
      candidate = mid;
      highBlock = mid - 1;
    }
  }
  return candidate;
}

module.exports = router;