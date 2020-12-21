// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

/**
 * @dev This library is provided for conveniece. It is the single source for
 *      the current network and all related hardcoded contract addresses. It
 *      also provide useful definitions for debuging faultless code via events.
 */
library $
{
	enum Network { Mainnet, Ropsten, Rinkeby, Kovan, Goerli }

	Network constant NETWORK = Network.Mainnet;

	bool constant DEBUG = NETWORK != Network.Mainnet;

	function debug(string memory _message) internal
	{
		address _from = msg.sender;
		if (DEBUG) emit Debug(_from, _message);
	}

	function debug(string memory _message, uint256 _value) internal
	{
		address _from = msg.sender;
		if (DEBUG) emit Debug(_from, _message, _value);
	}

	function debug(string memory _message, address _address) internal
	{
		address _from = msg.sender;
		if (DEBUG) emit Debug(_from, _message, _address);
	}

	event Debug(address indexed _from, string _message);
	event Debug(address indexed _from, string _message, uint256 _value);
	event Debug(address indexed _from, string _message, address _address);

	address constant stkGRO =
		NETWORK == Network.Mainnet ? 0xD93f98b483CC2F9EFE512696DF8F5deCB73F9497 :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		NETWORK == Network.Rinkeby ? 0x437664B64b88fDe761c54b3ab1568dA4227757fc :
		NETWORK == Network.Kovan ? 0x760FbB334dbbc15B9774e3d9fA0def86C0A6e7Af :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant GRO =
		NETWORK == Network.Mainnet ? 0x09e64c2B61a5f1690Ee6fbeD9baf5D6990F8dFd0 :
		NETWORK == Network.Ropsten ? 0x5BaF82B5Eddd5d64E03509F0a7dBa4Cbf88CF455 :
		NETWORK == Network.Rinkeby ? 0x020e317e70B406E23dF059F3656F6fc419411401 :
		NETWORK == Network.Kovan ? 0xFcB74f30d8949650AA524d8bF496218a20ce2db4 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant DAI =
		NETWORK == Network.Mainnet ? 0x6B175474E89094C44Da98b954EedeAC495271d0F :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant USDC =
		NETWORK == Network.Mainnet ? 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant USDT =
		NETWORK == Network.Mainnet ? 0xdAC17F958D2ee523a2206206994597C13D831ec7 :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant SUSD =
		NETWORK == Network.Mainnet ? 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51 :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant TUSD =
		NETWORK == Network.Mainnet ? 0x0000000000085d4780B73119b644AE5ecd22b376 :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant BUSD =
		NETWORK == Network.Mainnet ? 0x4Fabb145d64652a948d72533023f6E7A623C7C53 :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant WBTC =
		NETWORK == Network.Mainnet ? 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599 :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant WETH =
		NETWORK == Network.Mainnet ? 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 :
		NETWORK == Network.Ropsten ? 0xc778417E063141139Fce010982780140Aa0cD5Ab :
		NETWORK == Network.Rinkeby ? 0xc778417E063141139Fce010982780140Aa0cD5Ab :
		NETWORK == Network.Kovan ? 0xd0A1E359811322d97991E03f863a0C30C2cF029C :
		NETWORK == Network.Goerli ? 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6 :
		0x0000000000000000000000000000000000000000;

	address constant BAT =
		NETWORK == Network.Mainnet ? 0x0D8775F648430679A709E98d2b0Cb6250d2887EF :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant ENJ =
		NETWORK == Network.Mainnet ? 0xF629cBd94d3791C9250152BD8dfBDF380E2a3B9c :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant KNC =
		NETWORK == Network.Mainnet ? 0xdd974D5C2e2928deA5F71b9825b8b646686BD200 :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant AAVE =
		NETWORK == Network.Mainnet ? 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9 :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		NETWORK == Network.Kovan ? 0xB597cd8D3217ea6477232F9217fa70837ff667Af :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant LEND =
		NETWORK == Network.Mainnet ? 0x80fB784B7eD66730e8b1DBd9820aFD29931aab03 :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant LINK =
		NETWORK == Network.Mainnet ? 0x514910771AF9Ca656af840dff83E8264EcF986CA :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant MANA =
		NETWORK == Network.Mainnet ? 0x0F5D2fB29fb7d3CFeE444a200298f468908cC942 :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant MKR =
		NETWORK == Network.Mainnet ? 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2 :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant REN =
		NETWORK == Network.Mainnet ? 0x408e41876cCCDC0F92210600ef50372656052a38 :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant REP =
		NETWORK == Network.Mainnet ? 0x1985365e9f78359a9B6AD760e32412f4a445E862 :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant SNX =
		NETWORK == Network.Mainnet ? 0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant ZRX =
		NETWORK == Network.Mainnet ? 0xE41d2489571d322189246DaFA5ebDe1F4699F498 :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant UNI =
		NETWORK == Network.Mainnet ? 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984 :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant YFI =
		NETWORK == Network.Mainnet ? 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant cDAI =
		NETWORK == Network.Mainnet ? 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643 :
		NETWORK == Network.Ropsten ? 0xdb5Ed4605C11822811a39F94314fDb8F0fb59A2C :
		NETWORK == Network.Rinkeby ? 0x6D7F0754FFeb405d23C51CE938289d4835bE3b14 :
		NETWORK == Network.Kovan ? 0xF0d0EB522cfa50B716B3b1604C4F0fA6f04376AD :
		NETWORK == Network.Goerli ? 0x822397d9a55d0fefd20F5c4bCaB33C5F65bd28Eb :
		0x0000000000000000000000000000000000000000;

	address constant cUSDC =
		NETWORK == Network.Mainnet ? 0x39AA39c021dfbaE8faC545936693aC917d5E7563 :
		NETWORK == Network.Ropsten ? 0x8aF93cae804cC220D1A608d4FA54D1b6ca5EB361 :
		NETWORK == Network.Rinkeby ? 0x5B281A6DdA0B271e91ae35DE655Ad301C976edb1 :
		NETWORK == Network.Kovan ? 0x4a92E71227D294F041BD82dd8f78591B75140d63 :
		NETWORK == Network.Goerli ? 0xCEC4a43eBB02f9B80916F1c718338169d6d5C1F0 :
		0x0000000000000000000000000000000000000000;

	address constant cUSDT =
		NETWORK == Network.Mainnet ? 0xf650C3d88D12dB855b8bf7D11Be6C55A4e07dCC9 :
		NETWORK == Network.Ropsten ? 0x135669c2dcBd63F639582b313883F101a4497F76 :
		NETWORK == Network.Rinkeby ? 0x2fB298BDbeF468638AD6653FF8376575ea41e768 :
		NETWORK == Network.Kovan ? 0x3f0A0EA2f86baE6362CF9799B523BA06647Da018 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant cETH =
		NETWORK == Network.Mainnet ? 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5 :
		NETWORK == Network.Ropsten ? 0xBe839b6D93E3eA47eFFcCA1F27841C917a8794f3 :
		NETWORK == Network.Rinkeby ? 0xd6801a1DfFCd0a410336Ef88DeF4320D6DF1883e :
		NETWORK == Network.Kovan ? 0x41B5844f4680a8C38fBb695b7F9CFd1F64474a72 :
		NETWORK == Network.Goerli ? 0x20572e4c090f15667cF7378e16FaD2eA0e2f3EfF :
		0x0000000000000000000000000000000000000000;

	address constant cWBTC =
		NETWORK == Network.Mainnet ? 0xC11b1268C1A384e55C48c2391d8d480264A3A7F4 :
		NETWORK == Network.Ropsten ? 0x58145Bc5407D63dAF226e4870beeb744C588f149 :
		NETWORK == Network.Rinkeby ? 0x0014F450B8Ae7708593F4A46F8fa6E5D50620F96 :
		NETWORK == Network.Kovan ? 0xa1fAA15655B0e7b6B6470ED3d096390e6aD93Abb :
		NETWORK == Network.Goerli ? 0x6CE27497A64fFFb5517AA4aeE908b1E7EB63B9fF :
		0x0000000000000000000000000000000000000000;

	address constant cBAT =
		NETWORK == Network.Mainnet ? 0x6C8c6b02E7b2BE14d4fA6022Dfd6d75921D90E4E :
		NETWORK == Network.Ropsten ? 0x9E95c0b2412cE50C37a121622308e7a6177F819D :
		NETWORK == Network.Rinkeby ? 0xEBf1A11532b93a529b5bC942B4bAA98647913002 :
		NETWORK == Network.Kovan ? 0x4a77fAeE9650b09849Ff459eA1476eaB01606C7a :
		NETWORK == Network.Goerli ? 0xCCaF265E7492c0d9b7C2f0018bf6382Ba7f0148D :
		0x0000000000000000000000000000000000000000;

	address constant cZRX =
		NETWORK == Network.Mainnet ? 0xB3319f5D18Bc0D84dD1b4825Dcde5d5f7266d407 :
		NETWORK == Network.Ropsten ? 0x00e02a5200CE3D5b5743F5369Deb897946C88121 :
		NETWORK == Network.Rinkeby ? 0x52201ff1720134bBbBB2f6BC97Bf3715490EC19B :
		NETWORK == Network.Kovan ? 0xAf45ae737514C8427D373D50Cd979a242eC59e5a :
		NETWORK == Network.Goerli ? 0xA253295eC2157B8b69C44b2cb35360016DAa25b1 :
		0x0000000000000000000000000000000000000000;

	address constant cUNI =
		NETWORK == Network.Mainnet ? 0x35A18000230DA775CAc24873d00Ff85BccdeD550 :
		NETWORK == Network.Ropsten ? 0x22531F0f3a9c36Bfc3b04c4c60df5168A1cFCec3 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant cCOMP =
		NETWORK == Network.Mainnet ? 0x70e36f6BF80a52b3B46b3aF8e106CC0ed743E8e4 :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant COMP =
		NETWORK == Network.Mainnet ? 0xc00e94Cb662C3520282E6f5717214004A7f26888 :
		NETWORK == Network.Ropsten ? 0x1Fe16De955718CFAb7A44605458AB023838C2793 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		NETWORK == Network.Kovan ? 0x61460874a7196d6a22D1eE4922473664b3E95270 :
		NETWORK == Network.Goerli ? 0xe16C7165C8FeA64069802aE4c4c9C320783f2b6e :
		0x0000000000000000000000000000000000000000;

	address constant Aave_AAVE_LENDING_POOL_ADDRESSES_PROVIDER =
		NETWORK == Network.Mainnet ? 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8 :
		NETWORK == Network.Ropsten ? 0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		NETWORK == Network.Kovan ? 0x506B0B2CF20FAA8f38a4E2B524EE43e1f4458Cc5 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant Aave_AAVE_LENDING_POOL =
		NETWORK == Network.Mainnet ? 0x398eC7346DcD622eDc5ae82352F02bE94C62d119 :
		NETWORK == Network.Ropsten ? 0x9E5C7835E4b13368fd628196C4f1c6cEc89673Fa :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		NETWORK == Network.Kovan ? 0x580D4Fdc4BF8f9b5ae2fb9225D584fED4AD5375c :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant Aave_AAVE_LENDING_POOL_CORE =
		NETWORK == Network.Mainnet ? 0x3dfd23A6c5E8BbcFc9581d2E864a68feb6a076d3 :
		NETWORK == Network.Ropsten ? 0x4295Ee704716950A4dE7438086d6f0FBC0BA9472 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		NETWORK == Network.Kovan ? 0x95D1189Ed88B380E319dF73fF00E479fcc4CFa45 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant Balancer_FACTORY =
		NETWORK == Network.Mainnet ? 0x9424B1412450D0f8Fc2255FAf6046b98213B76Bd :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		NETWORK == Network.Rinkeby ? 0x9C84391B443ea3a48788079a5f98e2EaD55c9309 :
		NETWORK == Network.Kovan ? 0x8f7F78080219d4066A8036ccD30D588B416a40DB :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant Compound_COMPTROLLER =
		NETWORK == Network.Mainnet ? 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B :
		NETWORK == Network.Ropsten ? 0x54188bBeDD7b68228fa89CbDDa5e3e930459C6c6 :
		NETWORK == Network.Rinkeby ? 0x2EAa9D77AE4D8f9cdD9FAAcd44016E746485bddb :
		NETWORK == Network.Kovan ? 0x5eAe89DC1C671724A672ff0630122ee834098657 :
		NETWORK == Network.Goerli ? 0x627EA49279FD0dE89186A58b8758aD02B6Be2867 :
		0x0000000000000000000000000000000000000000;

	address constant Dydx_SOLO_MARGIN =
		NETWORK == Network.Mainnet ? 0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		NETWORK == Network.Kovan ? 0x4EC3570cADaAEE08Ae384779B0f3A45EF85289DE :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant Sushiswap_ROUTER02 =
		NETWORK == Network.Mainnet ? 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant UniswapV2_ROUTER02 =
		NETWORK == Network.Mainnet ? 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D :
		NETWORK == Network.Ropsten ? 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D :
		NETWORK == Network.Rinkeby ? 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D :
		NETWORK == Network.Kovan ? 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D :
		NETWORK == Network.Goerli ? 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D :
		0x0000000000000000000000000000000000000000;
}
