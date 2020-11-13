const names = [
  'stkGRO',
];

const G = artifacts.require('G');
const GTokenRegistry = artifacts.require('GTokenRegistry');

module.exports = async (deployer, network) => {
  const registry = await GTokenRegistry.deployed();
  for (const name of names) {
    const gXXX = artifacts.require(name);
    deployer.link(G, gXXX);
    const token = await deployer.deploy(gXXX);
    await registry.registerNewToken(token.address, '0x0000000000000000000000000000000000000000');
  }
};
