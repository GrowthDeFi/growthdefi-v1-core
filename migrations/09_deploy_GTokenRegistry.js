const GTokenRegistry = artifacts.require('GTokenRegistry');

module.exports = async (deployer) => {
  await deployer.deploy(GTokenRegistry);
};
