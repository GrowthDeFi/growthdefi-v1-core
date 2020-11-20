const names = [
  'gDAI', 'gUSDC', 'gUSDT',
  'gETH', 'gWBTC', 'gBAT', 'gZRX', 'gUNI', 'gCOMP',
  'gENJ', 'gKNC', 'gAAVE', 'gLINK', 'gMANA', 'gREN', 'gSNX', 'gYFI',
];

const G = artifacts.require('G');
const GLiquidityPoolManager = artifacts.require('GLiquidityPoolManager');
const GPortfolioReserveManager = artifacts.require('GPortfolioReserveManager');
const GUniswapV2Exchange = artifacts.require('GUniswapV2Exchange');
const GTokenRegistry = artifacts.require('GTokenRegistry');
const IERC20 = artifacts.require('IERC20');

module.exports = async (deployer, network) => {
  const registry = await GTokenRegistry.deployed();
  for (const name of names) {
    const gXXX = artifacts.require(name);
    deployer.link(G, gXXX);
    deployer.link(GLiquidityPoolManager, gXXX);
    deployer.link(GPortfolioReserveManager, gXXX);
    await deployer.deploy(gXXX);
    const token = await gXXX.deployed();
    if (!['ropsten', 'goerli'].includes(network)) {
      const value = `${1e18}`;
      const exchange = await GUniswapV2Exchange.deployed();
      const stoken = await IERC20.at(await token.stakesToken());
      const rtoken = await IERC20.at(await token.reserveToken());
      const samount = `${1e6}`;
      const gamount = `${1e6}`;
      const { '0': ramount } = await token.calcDepositCostFromShares(`${101e4}`, '0', '0', `${1e16}`);
      await exchange.faucet(stoken.address, samount, { value });
      await exchange.faucet(rtoken.address, ramount, { value });
      await stoken.approve(token.address, samount);
      await rtoken.approve(token.address, ramount);
      await token.deposit(ramount);
      await token.allocateLiquidityPool(samount, gamount);
    }
    await registry.registerNewToken(token.address, '0x0000000000000000000000000000000000000000');
  }
};
