const express = require("express");
const fs = require("fs");
const router = express.Router();

const {ethers, WebSocketProvider} = require("ethers");

const provider = new WebSocketProvider(
    `https://eth-mainnet.g.alchemy.com/v2/Ap2B9dlVZwl3n93PVT-r-oVrpG2XRCsR`
);

const contractAddress = "0x9D39A5DE30e57443BfF2A8307A4256c8797A3497";
const contractAbi = [ 
  "function totalAssets() view returns (uint256)"
];

const eventTopic = "0xbb28dd7cd6be6f61828ea9158a04c5182c716a946a6d2f31f4864edb87471aa6";

const logsFilter = {
  address: [contractAddress],
  fromBlock: "0x14A3909", 
  toBlock: "latest",
  topics: [ eventTopic ]
};

router.get("/ethena", async (req, res) => {
    try{
        const logs = await provider.getLogs(logsFilter);

        const contract = new ethers.Contract(contractAddress, contractAbi, provider);
      
        const results = [];

        for (const log of logs) {
          const dataNumber = BigInt(log.data);
      
          const totalAssetsPerBlock = await contract.totalAssets({ blockTag: log.blockNumber });

          const totalAssetsBigInt = BigInt(totalAssetsPerBlock);

          const blockInfo = await provider.getBlock(log.blockNumber);

          const numerator = dataNumber * 3n * 365n * 1000000n;

          const eightHourApy = (Number(numerator) / Number(totalAssetsBigInt)) / 1000000;

          const date = new Date(blockInfo.timestamp * 1000);

          results.push({
            blockNumber: log.blockNumber,
            rewards: dataNumber.toString(),              
            totalAssets: totalAssetsBigInt.toString(),
            date: date.toLocaleString(),
            apy: Number(eightHourApy)
          });
        }
      
        fs.writeFileSync("ethena-apy-eight-hours.json", JSON.stringify(results, null, 2));      
    } catch (error) {
        console.error("Error fetching: ", error);
        res.status(500).json({ error: "Failed to fetch data" });
    }
})

module.exports = router;