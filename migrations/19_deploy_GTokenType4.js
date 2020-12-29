const names = [
  'rAAVE',
];

const G = artifacts.require('G');
const GElasticTokenManager = artifacts.require('GElasticTokenManager');
const GPriceOracle = artifacts.require('GPriceOracle');
const GTokenRegistry = artifacts.require('GTokenRegistry');
const GUniswapV2Exchange = artifacts.require('GUniswapV2Exchange');
const Factory = artifacts.require('Factory');
const Pair = artifacts.require('Pair');
const IERC20 = artifacts.require('IERC20');

module.exports = async (deployer, network, accounts) => {
  const [account] = accounts;
  const registry = await GTokenRegistry.deployed();
  for (const name of names) {
    const GToken = artifacts.require(name);
    deployer.link(G, GToken);
    deployer.link(GElasticTokenManager, GToken);
    deployer.link(GPriceOracle, GToken);
    const supply = `${5e18}`;
    await deployer.deploy(GToken, supply);
    const token = await GToken.deployed();
    const rtoken = await IERC20.at(await token.referenceToken());
    // mint reference token
    const value = `${1e18}`;
    const exchange = await GUniswapV2Exchange.deployed();
    await exchange.faucet(rtoken.address, supply, { value });
    // create pool
    const factory = await Factory.at('0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f');
    await factory.createPair(token.address, rtoken.address);
    const pair = await Pair.at(await factory.getPair(token.address, rtoken.address));
    await token.transfer(pair.address, supply);
    await rtoken.transfer(pair.address, supply);
    await pair.mint(account);
    // activate rebase
    await token.activateOracle(pair.address);
    await token.activateRebase();
    await registry.registerNewToken(token.address, '0x0000000000000000000000000000000000000000');
  }
};
