const G = artifacts.require('G');
const GC = artifacts.require('GC');
const GCLeveragedReserveManager = artifacts.require('GCLeveragedReserveManager');

module.exports = async (deployer) => {
  deployer.link(G, GCLeveragedReserveManager);
  deployer.link(GC, GCLeveragedReserveManager);
  await deployer.deploy(GCLeveragedReserveManager);
};
