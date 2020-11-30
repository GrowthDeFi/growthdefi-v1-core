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
      await axios.post(url, { chat_id: telegramBotChatId, text: message, parse_mode: 'HTML' });
      lastMessage = message;
    } catch (e) {
      console.log('FAILURE', e.message);
    }
  }
}

// main

const ABI_ERC20 = require('../build/contracts/ERC20.json').abi;
const ABI_GTOKEN = require('../build/contracts/GToken.json').abi;
const ABI_GCTOKEN = require('../build/contracts/GCToken.json').abi;

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
  });
}

async function checkVitals(gctoken) {
  const lending = Number(await gctoken.lendingReserveUnderlying());
  const borrowing = Number(await gctoken.borrowingReserveUnderlying());
  const collateralizationRatio = (lending > 0 ? (100 * borrowing) / lending : 0).toFixed(2) + '%';
  return {
    collateralizationRatio,
  }
}

const DEFAULT_ADDRESS = {
  'gcDAI': {
    'mainnet': '0x4085669d375D7EBb225C05F6128e60C19079ee1c',
  },
  'gcUSDC': {
    'mainnet': '0x0e93b2D3969A0a6b71CE21Aa5be417cd4cAC38D0',
  },
  'gcETH': {
    'mainnet': '0xF510949599b90f78A0B40aae82539D09b9bE9e28',
  },
  'gcWBTC': {
    'mainnet': '0x1085045eF3f1564e4dA4C7315C0B7448d82d5D32',
  },
};

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
      const message = e instanceof Error ? e.message : String(message);
      await sendMessage('<i>Monitoring interrupted (' + message + ')</i>');
      exit();
    }
  });

  await sleep(60 * 1000);

  const names = [
    'gcDAI', 'gcUSDC', 'gcETH', 'gcWBTC',
  ];

  let gctokens = null;

  while (true) {
    let message;
    try {
      if (web3 === null) {
        web3 = new Web3(new HDWalletProvider(privateKey, HTTP_PROVIDER_URL[network]));
      }
      if (gctokens === null) {
        gctokens = await getTokens(names);
      }
      const lines = [];
      for (const gctoken of gctokens) {
        const vitals = await checkVitals(gctoken);
        const line = '<b><a href="https://etherscan.io/address/' + gctoken.address + '">' + gctoken.symbol + '</a></b> <i>' + vitals.collateralizationRatio + '</i>';
        lines.push(line);
      }
      message = lines.join('\n');
    } catch (e) {
      message = '<i>Monitoring failure (' + e.message + ')</i>';
    }
    await sendMessage(message);
    await sleep(60 * 1000);
  }
}

entrypoint(main);
