const tokens = {
  'gcETH': [['gETH', `${90e16}`]],
  'gcWBTC': [['gWBTC', `${90e16}`]],
  'gcBAT': [['gBAT', `${90e16}`]],
  'gcZRX': [['gZRX', `${90e16}`]],
  'gcUNI': [['gUNI', `${90e16}`]],
  'gcCOMP': [['gCOMP', `${90e16}`]],
}

const G = artifacts.require('G');
const GC = artifacts.require('GC');
const GLiquidityPoolManager = artifacts.require('GLiquidityPoolManager');
const GCDelegatedReserveManager = artifacts.require('GCDelegatedReserveManager');
const gDAI = artifacts.require('gDAI');
const GSushiswapExchange = artifacts.require('GSushiswapExchange');
const GUniswapV2Exchange = artifacts.require('GUniswapV2Exchange');
const GTokenRegistry = artifacts.require('GTokenRegistry');
const IERC20 = artifacts.require('IERC20');

module.exports = async (deployer, network) => {
  const registry = await GTokenRegistry.deployed();
  let exchange;
  if (['mainnet', 'development', 'testing'].includes(network)) {
    exchange = await GSushiswapExchange.deployed();
  } else {
    exchange = await GUniswapV2Exchange.deployed();
  }
  const dtoken = await gDAI.deployed();
  for (const name in tokens) {
    const GCToken = artifacts.require(name);
    deployer.link(G, GCToken);
    deployer.link(GC, GCToken);
    deployer.link(GLiquidityPoolManager, GCToken);
    deployer.link(GCDelegatedReserveManager, GCToken);
    await deployer.deploy(GCToken, dtoken.address);
    const token = await GCToken.deployed();
    if (!['rinkeby'].includes(network)) {
      await token.setExchange(exchange.address);
      await token.setMiningGulpRange(`${20e18}`, `${500e18}`);
      await token.setGrowthGulpRange(`${10000e6}`, `${20000e6}`);
    }
    if (!['ropsten', 'goerli'].includes(network)) {
      const value = `${1e18}`;
      const exchange = await GUniswapV2Exchange.deployed();
      const stoken = await IERC20.at(await token.stakesToken());
      const utoken = await IERC20.at(await token.underlyingToken());
      const samount = `${1e6}`;
      const gamount = `${1e6}`;
      const { '0': uamount } = await token.calcDepositUnderlyingCostFromShares(`${101e4}`, '0', '0', `${1e16}`, await token.exchangeRate());
      await exchange.faucet(stoken.address, samount, { value });
      await exchange.faucet(utoken.address, uamount, { value });
      await stoken.approve(token.address, samount);
      await utoken.approve(token.address, uamount);
      await token.depositUnderlying(uamount);
      await token.allocateLiquidityPool(samount, gamount);
    }
    await registry.registerNewToken(token.address, '0x0000000000000000000000000000000000000000');
    for (const [gname, percent] of tokens[name]) {
      const GToken = artifacts.require(gname);
      const gtoken = await GToken.deployed();
      const utoken = await IERC20.at(await token.underlyingToken());
      await gtoken.insertToken(token.address);
      await gtoken.transferTokenPercent(utoken.address, token.address, percent);
    }
  }
};
