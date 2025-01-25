const express = require("express");
const fs = require("fs");
const router = express.Router();

const {ethers, WebSocketProvider} = require("ethers");

const provider = new WebSocketProvider(
    `https://eth-mainnet.g.alchemy.com/v2/Ap2B9dlVZwl3n93PVT-r-oVrpG2XRCsR`
);

const CONTRACT_ADDRESS = "0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD";
const ABI = ["function ssr() view returns (uint256)"];

const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, provider);

const SECONDS_PER_YEAR = 365 * 24 * 60 * 60; 

const FILE_NAME = "sparkApy.json";

router.get("/spark", async (req, res) => {
  try {
    const latestBlockNum = await provider.getBlockNumber();
    const blockInfo = await provider.getBlock(latestBlockNum);

    const ssrBig = await contract.ssr();

    const ssrFloat = Number(ssrBig) / 1e27;

    const annualFactor = Math.pow(ssrFloat, SECONDS_PER_YEAR);

    const annualApy = (annualFactor - 1) * 100;

    const timestamp = new Date(blockInfo.timestamp * 1000).toLocaleString();
    const record = {
      blockNumber: latestBlockNum,
      timestamp,
      ssr: ssrBig.toString(),
      annualApy
    };

    let existingData = [];
    if (fs.existsSync(FILE_NAME)) {
      existingData = JSON.parse(fs.readFileSync(FILE_NAME, "utf-8"));
    }
    existingData.push(record);

    fs.writeFileSync(FILE_NAME, JSON.stringify(existingData, null, 2));
    console.log(`[${timestamp}] APY updated => ${annualApy.toFixed(4)}%`);
  } catch (err) {
    console.error("Error in storeApyHourly:", err);
  }
});

setInterval(() => {
  storeApyHourly().catch(console.error);
}, 3600000);

storeApyHourly().catch(console.error);

module.exports = routes;
