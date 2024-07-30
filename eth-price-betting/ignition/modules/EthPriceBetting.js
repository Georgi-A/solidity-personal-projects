const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const ONE_ETHER = 1_000_000_000_000_000_000n;

module.exports = buildModule("Betting", (m) => {
  const lockedAmount = m.getParameter("lockedAmount", ONE_GWEI);

  const ethPriceBetting = m.contract("EthPriceBetting", [60], {amount: lockedAmount});

  return {ethPriceBetting};

});