require('dotenv').config();
const axios = require('axios')
const Web3 = require('web3');
const HDWalletProvider = require('@truffle/hdwallet-provider');

// process

function idle() {
  return new Promise((resolve, reject) => { });
}

function sleep(delay) {
  return new Promise((resolve, reject) => setTimeout(resolve, delay));
}

function abort(e) {
  e = e || new Error('Program aborted');
  console.error(e.stack);
  process.exit(1);
}

function exit() {
  process.exit(0);
}

function interrupt(f) {
  process.on('SIGINT', f);
  process.on('SIGTERM', f);
  process.on('SIGUSR1', f);
  process.on('SIGUSR2', f);
  process.on('uncaughtException', f);
  process.on('unhandledRejection', f);
}

function entrypoint(main) {
  const args = process.argv;
  (async () => { try { await main(args); } catch (e) { abort(e); } exit(); })();
}

// web3

const network = process.env['NETWORK'] || 'development';

const infuraProjectId = process.env['INFURA_PROJECT_ID'] || '';

const testServer = process.env['TEST_SERVER'] || '';

const privateKey = process.env['PRIVATE_KEY'];
if (!privateKey) throw new Error('Unknown private key');

const NETWORK_ID = {
  'mainnet': '1',
  'ropsten': '3',
  'rinkeby': '4',
  'kovan': '42',
  'goerli': '5',
  'development': '1',
  'testing': '1',
};

const networkId = NETWORK_ID[network];

const HTTP_PROVIDER_URL = {
  'mainnet': 'https://mainnet.infura.io/v3/' + infuraProjectId,
  'ropsten': 'https://ropsten.infura.io/v3/' + infuraProjectId,
  'rinkeby': 'https://rinkeby.infura.io/v3/' + infuraProjectId,
  'kovan': 'https://kovan.infura.io/v3/' + infuraProjectId,
  'goerli': 'https://goerli.infura.io/v3/' + infuraProjectId,
  'development': 'http://localhost:8545/',
  'testing': 'http://' + testServer + ':8545/',
};

const WEBSOCKET_PROVIDER_URL = {
  'mainnet': 'wss://mainnet.infura.io/ws/v3/' + infuraProjectId,
  'ropsten': 'wss://ropsten.infura.io/ws/v3/' + infuraProjectId,
  'rinkeby': 'wss://rinkeby.infura.io/ws/v3/' + infuraProjectId,
  'kovan': 'wss://kovan.infura.io/ws/v3/' + infuraProjectId,
  'goerli': 'wss://goerli.infura.io/ws/v3/' + infuraProjectId,
  'development': 'http://localhost:8545/',
  'testing': 'http://' + testServer + ':8545/',
};

let web3 = null;
/*
const web3ws = new Web3(new Web3.providers.HttpProvider(HTTP_PROVIDER_URL[network]));

function connect() {
  const provider = new Web3.providers.WebsocketProvider(WEBSOCKET_PROVIDER_URL[network]);
  provider.on('error', () => abort(new Error('Connection error')));
  provider.on('end', connect);
  web3ws.setProvider(provider);
}

connect();

function blockSubscribe(f) {
  const subscription = web3ws.eth.subscribe('newBlockHeaders', (e, block) => {
    if (e) return abort(e);
    try {
      const { number } = block;
      f(number);
    } catch (e) {
      abort(e);
    }
  });
  return () => subscription.unsubscribe((e, success) => {
    if (e) return abort(e);
  });
}

function logSubscribe(events, f) {
  const topics = events.map(web3.eth.abi.encodeEventSignature);
  const params = events.map((event) => {
    const result = event.match(/\((.*)\)/);
    if (!result) throw new Error('Invalid event');
    const [, args] = result;
    if (args == '') return [];
    return args.split(',');
  });
  const map = {};
  for (const i in topics) map[topics[i]] = [events[i], params[i]];
  const subscription = web3ws.eth.subscribe('logs', { topics: [topics] }, (e, log) => {
    if (e) return abort(e);
    try {
      const { address, topics: [topic, ...values], data } = log;
      const [event, params] = map[topic];
      for (const i in values) values[i] = String(web3.eth.abi.decodeParameter(params[i], values[i]));
      const missing = params.slice(values.length);
      const result = web3.eth.abi.decodeParameters(missing, data);
      for (const i in missing) values.push(result[i]);
      f(address, event, values);
    } catch (e) {
      abort(e);
    }
  });
  return () => subscription.unsubscribe((e, success) => {
    if (e) return abort(e);
  });
}
*/

function valid(amount, decimals) {
  const regex = new RegExp(`^\\d+${decimals > 0 ? `(\\.\\d{1,${decimals}})?` : ''}$`);
  return regex.test(amount);
}

function coins(units, decimals) {
  if (!valid(units, 0)) throw new Error('Invalid amount');
  if (decimals == 0) return units;
  const s = units.padStart(1 + decimals, '0');
  return s.slice(0, -decimals) + '.' + s.slice(-decimals);
}

function units(coins, decimals) {
  if (!valid(coins, decimals)) throw new Error('Invalid amount');
  let i = coins.indexOf('.');
  if (i < 0) i = coins.length;
  const s = coins.slice(i + 1);
  return coins.slice(0, i) + s + '0'.repeat(decimals - s.length);
}

// telegram

const telegramBotApiKey = process.env['TELEGRAM_BOT_API_KEY'];
if (!telegramBotApiKey) throw new Error('Unknown telegram bot api key');

const telegramBotChatId = process.env['TELEGRAM_BOT_CHAT_ID'];
if (!telegramBotChatId) throw new Error('Unknown telegram bot chat id');

let lastMessage = '';

async function sendMessage(message) {
  if (message !== lastMessage) {
    console.log(new Date().toISOString());
    console.log(message);
    try {
      const url = 'https://api.telegram.org/bot'+ telegramBotApiKey +'/sendMessage';
      await axios.post(url, { chat_id: telegramBotChatId, text: message, parse_mode: 'HTML', disable_web_page_preview: true });
      lastMessage = message;
    } catch (e) {
      console.log('FAILURE', e.message);
    }
  }
}

// main

function getAccount() {
  const [account] = web3.currentProvider.getAddresses();
  return account;
}

async function getCurrentNonce() {
  const account = getAccount();
  return await web3.eth.getTransactionCount(account);
}

async function getEthBalance() {
  const account = getAccount();
  const amount = await web3.eth.getBalance(account);
  return coins(amount, 18);
}

const ABI_ERC20 = require('../build/contracts/GTokenBase.json').abi;
const ABI_GTOKEN = require('../build/contracts/GTokenBase.json').abi;
const ABI_GCTOKEN = require('../build/contracts/GCTokenBase.json').abi;
const ABI_COMPTROLLER = require('../build/contracts/Comptroller.json').abi;

async function newERC20(address) {
  let self;
  const contract = new web3.eth.Contract(ABI_ERC20, address);
  const [name, symbol, _decimals] = await Promise.all([
    contract.methods.name().call(),
    contract.methods.symbol().call(),
    contract.methods.decimals().call(),
  ]);
  const decimals = Number(_decimals);
  return (self = {
    address,
    name,
    symbol,
    decimals,
    totalSupply: async () => {
      const amount = await contract.methods.totalSupply().call();
      return coins(amount, decimals);
    },
    balanceOf: async (owner) => {
      const amount = await contract.methods.balanceOf(owner).call();
      return coins(amount, decimals);
    },
  });
}

async function newGToken(address) {
  let self;
  const fields = await newERC20(address);
  const contract = new web3.eth.Contract(ABI_GTOKEN, address);
  const stakesToken = await newERC20(await contract.methods.stakesToken().call());
  const reserveToken = await newERC20(await contract.methods.reserveToken().call());
  return (self = {
    ...fields,
    stakesToken,
    reserveToken,
    totalReserve: async () => {
      const amount = await contract.methods.totalReserve().call();
      return coins(amount, self.reserveToken.decimals);
    },
  });
}

async function newGCToken(address) {
  let self;
  const fields = await newGToken(address);
  const contract = new web3.eth.Contract(ABI_GCTOKEN, address);
  const underlyingToken = await newERC20(await contract.methods.underlyingToken().call());
  return (self = {
    ...fields,
    underlyingToken,
    lendingReserveUnderlying: async () => {
      const _amount = await contract.methods.lendingReserveUnderlying().call();
      return coins(_amount, underlyingToken.decimals);
    },
    borrowingReserveUnderlying: async () => {
      const _amount = await contract.methods.borrowingReserveUnderlying().call();
      return coins(_amount, underlyingToken.decimals);
    },
    depositUnderlying: async (cost, gasPrice, nonce) => {
      const account = getAccount();
      const _cost = units(cost, self.underlyingToken.decimals);
      const { transactionHash } = await contract.methods.depositUnderlying(_cost).send({ from: account, gasPrice, nonce });
      return transactionHash;
    },
    withdrawUnderlying: async (grossShares, gasPrice, nonce) => {
      const account = getAccount();
      const _grossShares = units(grossShares, self.decimals);
      const { transactionHash } = await contract.methods.withdrawUnderlying(_grossShares).send({ from: account, gasPrice, nonce });
      return transactionHash;
    },
  });
}

async function newComptroller(address) {
  let self;
  const contract = new web3.eth.Contract(ABI_COMPTROLLER, address);
  return (self = {
    markets: async (ctoken) => {
      let { _isListed, _collateralFactorMantissa } = await contract.methods.markets(ctoken).call();
      _collateralFactorMantissa = _collateralFactorMantissa / 1e18;
      return { _isListed, _collateralFactorMantissa };
    },
  });
}

const MONITORING_INTERVAL = 60; // 1 minute

const POLLING_TIMEOUT = 20; // 20 seconds
const POLLING_INTERVAL = 60; // 1 minute

const INITIAL_GAS_PRICE = 50e9; // 50 gwei
const GAS_PRICE_INCREMENT = 100e9; // 100 gwei

const MININUM_BALANCE_FACTOR = 10; // 10x

const SAFE_TOKEN_MARGIN = {
  'gcDAI': 0.01, // 1%
  'gcUSDC': 0.01, // 1%
  'gcETH': 0.05, // 5%
  'gcWBTC': 0.05, // 5%
};

const DEPOSIT_AMOUNT = {
  'ETH': '0.1',
  'DAI': '0.001',
  'USDC': '0.001',
  'WETH': '0.00001',
  'WBTC': '0.00001',
};

async function getMaxCollateralizationRatio(gctoken) {
  const address = getContractAddress('Comptroller');
  const comptroller = await newComptroller(address);
  const { _collateralFactorMantissa } = await comptroller.markets(gctoken.reserveToken.address);
  return _collateralFactorMantissa;
}

async function checkVitals(gctoken) {
  const account = getAccount();
  const lending = Number(await gctoken.lendingReserveUnderlying());
  const borrowing = Number(await gctoken.borrowingReserveUnderlying());
  const collateralizationRatio = lending > 0 ? borrowing / lending : 0;
  const maxCollateralizationRatio = await getMaxCollateralizationRatio(gctoken);
  const safeMargin = SAFE_TOKEN_MARGIN[gctoken.symbol] || 0.05;
  const criticalCollateralizationRatio = maxCollateralizationRatio - safeMargin;
  const underlyingBalance = await gctoken.underlyingToken.balanceOf(account);
  const underlyingSymbol = await gctoken.underlyingToken.symbol;
  return {
    collateralizationRatio,
    maxCollateralizationRatio,
    criticalCollateralizationRatio,
    underlyingBalance,
    underlyingSymbol,
  }
}

async function handleCritical(gctoken) {
  await sendMessage('<i>Entering critical mode for ' + gctoken.symbol + '</i>');
  const amount = DEPOSIT_AMOUNT[gctoken.symbol] || '1';
  const initialNonce = await getCurrentNonce();
  let nonce = initialNonce;
  for (let gasPrice = INITIAL_GAS_PRICE; nonce === initialNonce; gasPrice += GAS_PRICE_INCREMENT) {
    let txhash = '';
    let error = null;
    try { txhash = await gctoken.depositUnderlying(amount, gasPrice, nonce); } catch (e) { error = e; }
    await sendMessage('<i>Deposit amount=' + amount + ' gasPrice=' + gasPrice + ' nonce=' + nonce + (txhash ? ' txhash=' + txhash : '') + (error ? ' error="' + error.message + '"' : '') + '</i>');
    await sleep(POLLING_INTERVAL * 1000);
    nonce = await getCurrentNonce();
  }
  await sendMessage('<i>Leaving critical mode for ' + gctoken.symbol + '</i>');
}

const DEFAULT_ADDRESS = {
  'Comptroller': {
    'mainnet': '0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B',
    'kovan': '0x5eAe89DC1C671724A672ff0630122ee834098657',
  },
  'gcDAI': {
    'mainnet': '0x4085669d375D7EBb225C05F6128e60C19079ee1c',
    'kovan': '0x8Cde5552602DB7563f424d105217e098d96fce36',
  },
  'gcUSDC': {
    'mainnet': '0x0e93b2D3969A0a6b71CE21Aa5be417cd4cAC38D0',
    'kovan': '0x151ac053B6EEEB604c957f2E1F69F797834DB39b',
  },
  'gcETH': {
    'mainnet': '0xF510949599b90f78A0B40aae82539D09b9bE9e28',
    'kovan': '0x9Ca66B0165fF06066cd4f39731bBD2797E4E0691',
  },
  'gcWBTC': {
    'mainnet': '0x1085045eF3f1564e4dA4C7315C0B7448d82d5D32',
    'kovan': '0xb389dc7A147065c0F0572b8c3340F6F01D427751',
  },
};

const URL_PREFIX = {
  'mainnet': 'https://etherscan.io/address/',
  'ropsten': 'https://ropsten.etherscan.io/address/',
  'rinkeby': 'https://rinkeby.etherscan.io/address/',
  'kovan': 'https://kovan.etherscan.io/address/',
  'goerli': 'https://goerli.etherscan.io/address/',
  'development': '',
  'testing': '',
}

function getContractAddress(name) {
  return (DEFAULT_ADDRESS[name] || {})[network] || require('../build/contracts/' + name + '.json').networks[networkId].address;
}

async function getTokens(names) {
  const gctokens = [];
  for (const name of names) {
    const address = getContractAddress(name);
    const gctoken = await newGCToken(address);
    gctokens.push(gctoken);
  }
  return gctokens;
}

async function main(args) {
  await sendMessage('<i>Monitoring initiated</i>');

  let interrupted = false;
  interrupt(async (e) => {
    if (!interrupted) {
      interrupted = true;
      const message = e instanceof Error ? e.message : String(e);
      await sendMessage('<i>Monitoring interrupted (' + message + ')</i>');
      exit();
    }
  });

  await sleep(MONITORING_INTERVAL * 1000);

  const names = [
    'gcDAI', 'gcUSDC', 'gcETH', 'gcWBTC',
  ];

  let gctokens = null;

  while (true) {
    let message;
    let criticalList = [];
    try {
      if (web3 === null) {
        web3 = new Web3(new HDWalletProvider(privateKey, HTTP_PROVIDER_URL[network]));
        web3.eth.transactionPollingTimeout = POLLING_TIMEOUT;
      }
      if (gctokens === null) {
        gctokens = await getTokens(names);
      }
      const lines = [];
      {
        const account = getAccount();
        const symbol = 'ETH';
        const curBalance = await getEthBalance();
        const minBalance = MININUM_BALANCE_FACTOR * Number(DEPOSIT_AMOUNT[symbol] || '1');
        const lowBalance = curBalance < minBalance;

        const curBalanceText = curBalance + ' ' + symbol;
        const minBalanceText = minBalance + ' ' + symbol;

        lines.push('<a href="' + URL_PREFIX[network] + account + '"><b>Bot Address</b></a>');
        lines.push('balance: ' + curBalanceText);
        if (lowBalance) lines.push('!!LOW!! balance &lt; ' + minBalanceText);
        lines.push('');
      }
      for (const gctoken of gctokens) {
        const vitals = await checkVitals(gctoken);
        const criticalLevel = vitals.collateralizationRatio >= vitals.criticalCollateralizationRatio;
        const symbol = vitals.underlyingSymbol;
        const curBalance = Number(vitals.underlyingBalance);
        const minBalance = MININUM_BALANCE_FACTOR * Number(DEPOSIT_AMOUNT[symbol] || '1');
        const lowBalance = curBalance < minBalance;

        const curRatioText = (100 * vitals.collateralizationRatio).toFixed(2) + '%';
        const ctcRatioText = (100 * vitals.criticalCollateralizationRatio).toFixed(2) + '%';
        const maxRatioText = (100 * vitals.maxCollateralizationRatio).toFixed(2) + '%';
        const ratioText = curRatioText + ' of ' + maxRatioText;

        const curBalanceText = curBalance + ' ' + symbol;
        const minBalanceText = minBalance + ' ' + symbol;

        lines.push('<a href="' + URL_PREFIX[network] + gctoken.address + '"><b>' + gctoken.symbol + '</b></a>');
        lines.push('ratio: ' + ratioText);
        lines.push('balance: ' + curBalanceText);
        if (criticalLevel) lines.push('!!CRITICAL!! ratio &gt;= ' + ctcRatioText);
        if (lowBalance) lines.push('!!LOW!! balance &lt; ' + minBalanceText);
        lines.push('');

	if (criticalLevel) criticalList.push(gctoken);
      }
      message = lines.join('\n');
    } catch (e) {
      message = '<i>Monitoring failure (' + e.message + ')</i>';
    }
    await sendMessage(message);
    for (const gctoken of criticalList) {
      await handleCritical(gctoken);
    }
    await sleep(MONITORING_INTERVAL * 1000);
  }
}

entrypoint(main);
