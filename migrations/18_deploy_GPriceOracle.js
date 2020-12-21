const GPriceOracle = artifacts.require('GPriceOracle');

module.exports = async (deployer) => {
  await deployer.deploy(GPriceOracle);
};
