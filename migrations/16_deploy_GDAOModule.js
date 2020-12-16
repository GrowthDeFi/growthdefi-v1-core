const G = artifacts.require('G');
const stkGRO = artifacts.require('stkGRO');
const GDAOModule = artifacts.require('GDAOModule');

module.exports = async (deployer, network) => {
  let multisig;
  if (['mainnet', 'development', 'testing'].includes(network)) {
    multisig = '0x3E7Ff81efBbAdf5FCA2810086b7f4C17a4F3682f';
  }
  else
  if (['rinkeby'].includes(network)) {
    multisig = '0xF074450e1bCB367822f6b9deED2f4784a2a6A5cF';
  }
  else return;
  const vtoken = await stkGRO.deployed();
  deployer.link(G, GDAOModule);
  await deployer.deploy(GDAOModule, multisig, vtoken.address);
};
