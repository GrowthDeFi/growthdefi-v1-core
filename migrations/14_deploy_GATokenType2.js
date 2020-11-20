const tokens = {
  'gacENJ': [['gENJ', `${90e16}`]],
  'gacKNC': [['gKNC', `${90e16}`]],
  'gacAAVE': [['gAAVE', `${90e16}`]],
  'gacLINK': [['gLINK', `${90e16}`]],
  'gacMANA': [['gMANA', `${90e16}`]],
  'gacREN': [['gREN', `${90e16}`]],
  'gacSNX': [['gSNX', `${90e16}`]],
  'gacYFI': [['gYFI', `${90e16}`]],
}

const G = artifacts.require('G');
const GA = artifacts.require('GA');
const GLiquidityPoolManager = artifacts.require('GLiquidityPoolManager');
const GADelegatedReserveManager = artifacts.require('GADelegatedReserveManager');
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
  const gatoken = await gDAI.deployed();
  for (const name in tokens) {
    const gaXXX = artifacts.require(name);
    deployer.link(G, gaXXX);
    deployer.link(GA, gaXXX);
    deployer.link(GLiquidityPoolManager, gaXXX);
    deployer.link(GADelegatedReserveManager, gaXXX);
    await deployer.deploy(gaXXX, gatoken.address);
    const token = await gaXXX.deployed();
    if (!['ropsten', 'rinkeby', 'kovan', 'goerli'].includes(network)) {
      await token.setExchange(exchange.address);
      await token.setGrowthGulpRange(`${10000e6}`, `${20000e6}`);
    }
    if (!['mainnet', 'development', 'testing'].includes(network)) {
      await token.setCollateralizationRatio('0', '0');
    }
    if (!['ropsten', 'goerli'].includes(network)) {
      const value = `${1e18}`;
      const exchange = await GUniswapV2Exchange.deployed();
      const stoken = await IERC20.at(await token.stakesToken());
      const utoken = await IERC20.at(await token.underlyingToken());
      const samount = `${1e14}`;
      const gamount = `${1e14}`;
      const { '0': uamount } = await token.calcDepositUnderlyingCostFromShares(`${101e12}`, '0', '0', `${1e16}`, await token.exchangeRate());
      await exchange.faucet(stoken.address, samount, { value });
      await exchange.faucet(utoken.address, uamount, { value });
      await stoken.approve(token.address, samount);
      await utoken.approve(token.address, uamount);
      await token.depositUnderlying(uamount);
      await token.allocateLiquidityPool(samount, gamount);
    }
    await registry.registerNewToken(token.address, '0x0000000000000000000000000000000000000000');
    for (const [gname, percent] of tokens[name]) {
      const gXXX = artifacts.require(gname);
      const gtoken = await gXXX.deployed();
      const utoken = await IERC20.at(await token.underlyingToken());
      await gtoken.insertToken(token.address);
      await gtoken.transferTokenPercent(utoken.address, token.address, percent);
    }
  }
};
