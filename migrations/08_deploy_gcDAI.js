const G = artifacts.require('G');
const GLiquidityPoolManager = artifacts.require('GLiquidityPoolManager');
const GCLeveragedReserveManager = artifacts.require('GCLeveragedReserveManager');
const gcDAI = artifacts.require('gcDAI');
const GSushiswapExchange = artifacts.require('GSushiswapExchange');
const GUniswapV2Exchange = artifacts.require('GUniswapV2Exchange');
const GTokenRegistry = artifacts.require('GTokenRegistry');
const IERC20 = artifacts.require('IERC20');

module.exports = async (deployer, network) => {
  if (['ropsten', 'rinkeby', 'goerli'].includes(network)) return;
  deployer.link(G, gcDAI);
  deployer.link(GLiquidityPoolManager, gcDAI);
  deployer.link(GCLeveragedReserveManager, gcDAI);
  await deployer.deploy(gcDAI);
  let exchange
  if (['mainnet', 'development', 'testing'].includes(network)) {
    exchange = await GSushiswapExchange.deployed();
  } else {
    exchange = await GUniswapV2Exchange.deployed();
  }
  const token = await gcDAI.deployed();
  await token.setExchange(exchange.address);
  await token.setMiningGulpRange(`${20e18}`, `${500e18}`);
  if (!['mainnet', 'development', 'testing'].includes(network)) {
	await token.setCollateralizationRatio('0', '0');
  }
  if (!['mainnet'].includes(network)) {
    const value = `${1e18}`;
    const exchange = await GUniswapV2Exchange.deployed();
    const stoken = await IERC20.at(await token.stakesToken());
    const utoken = await IERC20.at(await token.underlyingToken());
    const samount = `${1e6}`;
    const gamount = `${1e6}`;
    const { '0': uamount } = await token.calcDepositUnderlyingCostFromShares(`${101e4}`, '0', '0', '0', await token.exchangeRate());
    await exchange.faucet(stoken.address, samount, { value });
    await exchange.faucet(utoken.address, uamount, { value });
    await stoken.approve(token.address, samount);
    await utoken.approve(token.address, uamount);
    await token.depositUnderlying(uamount);
    await token.allocateLiquidityPool(samount, gamount);
  }
  const registry = await GTokenRegistry.deployed();
  await registry.registerNewToken(token.address);
};