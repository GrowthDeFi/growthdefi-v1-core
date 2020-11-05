const G = artifacts.require('G');
const GSushiswapExchange = artifacts.require('GSushiswapExchange');
const GUniswapV2Exchange = artifacts.require('GUniswapV2Exchange');

module.exports = async (deployer) => {
  deployer.link(G, GSushiswapExchange);
  await deployer.deploy(GSushiswapExchange);
  deployer.link(G, GUniswapV2Exchange);
  await deployer.deploy(GUniswapV2Exchange);
};
