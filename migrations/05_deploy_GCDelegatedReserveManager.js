const G = artifacts.require('G');
const GC = artifacts.require('GC');
const GCDelegatedReserveManager = artifacts.require('GCDelegatedReserveManager');

module.exports = async (deployer) => {
  deployer.link(G, GCDelegatedReserveManager);
  deployer.link(GC, GCDelegatedReserveManager);
  await deployer.deploy(GCDelegatedReserveManager);
};
