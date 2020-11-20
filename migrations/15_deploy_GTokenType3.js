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
    await deployer.deploy(gXXX);
    const token = await gXXX.deployed();
    await registry.registerNewToken(token.address, '0x0000000000000000000000000000000000000000');
  }
};
