const GElasticTokenManager = artifacts.require('GElasticTokenManager');

module.exports = async (deployer) => {
  await deployer.deploy(GElasticTokenManager);
};
