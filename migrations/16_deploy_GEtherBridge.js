const G = artifacts.require('G');
const GEtherBridge = artifacts.require('GEtherBridge');

module.exports = async (deployer) => {
  deployer.link(G, GEtherBridge);
  await deployer.deploy(GEtherBridge);
};
