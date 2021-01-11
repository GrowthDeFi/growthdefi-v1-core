const G = artifacts.require('G');
const GA = artifacts.require('GA');
const GADelegatedReserveManager = artifacts.require('GADelegatedReserveManager');

module.exports = async (deployer) => {
  deployer.link(G, GADelegatedReserveManager);
  deployer.link(GA, GADelegatedReserveManager);
  await deployer.deploy(GADelegatedReserveManager);
};
