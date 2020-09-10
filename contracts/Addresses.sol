// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

contract Addresses
{
	enum Network { Mainnet, Ropsten, Rinkeby, Kovan, Goerli }

	Network constant NETWORK = Network.Mainnet;

	address constant GRO =
		NETWORK == Network.Mainnet ? 0x09e64c2B61a5f1690Ee6fbeD9baf5D6990F8dFd0 :
		NETWORK == Network.Ropsten ? 0x5BaF82B5Eddd5d64E03509F0a7dBa4Cbf88CF455 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant DAI =
		NETWORK == Network.Mainnet ? 0x6B175474E89094C44Da98b954EedeAC495271d0F :
		NETWORK == Network.Ropsten ? 0xc2118d4d90b274016cB7a54c03EF52E6c537D957 :
		NETWORK == Network.Rinkeby ? 0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa :
		NETWORK == Network.Kovan ? 0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant USDC =
		NETWORK == Network.Mainnet ? 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 :
		NETWORK == Network.Ropsten ? 0x0D9C8723B343A8368BebE0B5E89273fF8D712e3C :
		NETWORK == Network.Rinkeby ? 0x4DBCdF9B62e891a7cec5A2568C3F4FAF9E8Abe2b :
		NETWORK == Network.Kovan ? 0xb7a4F3E9097C08dA09517b5aB877F7a917224ede :
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

	address constant COMP =
		NETWORK == Network.Mainnet ? 0xc00e94Cb662C3520282E6f5717214004A7f26888 :
		NETWORK == Network.Ropsten ? 0x1Fe16De955718CFAb7A44605458AB023838C2793 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		NETWORK == Network.Kovan ? 0x61460874a7196d6a22D1eE4922473664b3E95270 :
		NETWORK == Network.Goerli ? 0xe16C7165C8FeA64069802aE4c4c9C320783f2b6e :
		0x0000000000000000000000000000000000000000;

	address constant Compound_Comptroller =
		NETWORK == Network.Mainnet ? 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B :
		NETWORK == Network.Ropsten ? 0x54188bBeDD7b68228fa89CbDDa5e3e930459C6c6 :
		NETWORK == Network.Rinkeby ? 0x2EAa9D77AE4D8f9cdD9FAAcd44016E746485bddb :
		NETWORK == Network.Kovan ? 0x5eAe89DC1C671724A672ff0630122ee834098657 :
		NETWORK == Network.Goerli ? 0x627EA49279FD0dE89186A58b8758aD02B6Be2867 :
		0x0000000000000000000000000000000000000000;

	address constant Balancer_Factory =
		NETWORK == Network.Mainnet ? 0x9424B1412450D0f8Fc2255FAf6046b98213B76Bd :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		NETWORK == Network.Kovan ? 0x8f7F78080219d4066A8036ccD30D588B416a40DB :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant Oneinch_Exchange =
		NETWORK == Network.Mainnet ? 0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E :
		// NETWORK == Network.Ropsten ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Rinkeby ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Kovan ? 0x0000000000000000000000000000000000000000 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;
}
