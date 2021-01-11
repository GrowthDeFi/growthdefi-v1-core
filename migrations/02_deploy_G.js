const G = artifacts.require('G');
const GC = artifacts.require('GC');
const GA = artifacts.require('GA');

module.exports = async (deployer) => {
  await deployer.deploy(G);
  await deployer.deploy(GC);
  await deployer.deploy(GA);
};
