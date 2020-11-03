const G = artifacts.require('G');
const GPortfolioReserveManager = artifacts.require('GPortfolioReserveManager');

module.exports = async (deployer) => {
  deployer.link(G, GPortfolioReserveManager);
  await deployer.deploy(GPortfolioReserveManager);
};
