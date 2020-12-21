const names = [
  'rAAVE',
];

const G = artifacts.require('G');
const GTokenRegistry = artifacts.require('GElasticTokenManager');
const GTokenRegistry = artifacts.require('GPriceOracle');
const GTokenRegistry = artifacts.require('GTokenRegistry');

module.exports = async (deployer, network) => {
  const registry = await GTokenRegistry.deployed();
  for (const name of names) {
    const GToken = artifacts.require(name);
    deployer.link(GElasticTokenManager, GToken);
    deployer.link(GPriceOracle, GToken);
    deployer.link(G, GToken);
    await deployer.deploy(GToken, `${200e18}`);
    const token = await GToken.deployed();
    await registry.registerNewToken(token.address, '0x0000000000000000000000000000000000000000');
  }
};
