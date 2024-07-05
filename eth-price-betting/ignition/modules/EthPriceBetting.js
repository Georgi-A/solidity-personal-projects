const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("Betting", (m) => {

  const priceAlert = m.contract("EthPriceBetting", [60]);

  return {priceAlert};

});