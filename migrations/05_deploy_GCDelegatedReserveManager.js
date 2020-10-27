const G = artifacts.require('G');
const GCDelegatedReserveManager = artifacts.require('GCDelegatedReserveManager');

module.exports = async (deployer) => {
  deployer.link(G, GCDelegatedReserveManager);
  await deployer.deploy(GCDelegatedReserveManager);
};
