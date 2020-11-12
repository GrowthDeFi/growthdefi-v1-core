# GrowthDeFi V1 Core

[![Truffle CI Actions Status](https://github.com/GrowthDeFi/growthdefi-v1-core/workflows/Truffle%20CI/badge.svg)](https://github.com/GrowthDeFi/growthdefi-v1-core/actions)

This repository contains the source code for the GrowthDeFi smart contracts
(Version 1) and related support code for testing and monitoring the contracts.

## Deployed Contracts

| Token  | Mainnet Address                                                                                                       |
| ------ | --------------------------------------------------------------------------------------------------------------------- |
| gcDAI  | [0x8c659d745eB24DF270A952F68F4B1d6817c3795C](https://etherscan.io/address/0x8c659d745eB24DF270A952F68F4B1d6817c3795C) |
| gcUSDC | [0x3C918ab39C4680d3eBb3EAFcA91C3494F372a20D](https://etherscan.io/address/0x3C918ab39C4680d3eBb3EAFcA91C3494F372a20D) |

## Repository Organization

* [/contracts/](contracts). This folder is where the smart contract source code
  resides.
* [/docker/](docker). This folder contains docker and/or docker-compose files
  that help setting up and running a ganache-cli service for testing and
  development.
* [/migrations/](migrations). This folder hosts the relevant set of Truffle
  migration scripts used to publish the smart contracts to the blockchain.
* [/stress-test/](stress-test). This folder contains code to assist in stress
  testing the core contract functionality by performing a sequence of random
  operations.
* [/telegram-bot/](telegram-bot). This folder contains code to assist in
  monitoring the smart contract health/vitals in real time via Telegram
  notifications.
* [/test/](test). This folder contains a set of relevant unit tests for Truffle
  written in Solidity.

## Source Code

The smart contracts are written in Solidity and the source code is organized in
the following folder structure:

* [/contracts/](contracts). This folder has the core functionality with the main
  contract hierarchy and supporting functionality. This is further described
  in detail below.
* [/contracts/interop/](contracts/interop). This folder contains the minimal
  interoperability interfaces to other services such as Aave, Compound, Curve,
  DyDx, etc.
* [/contracts/modules/](contracts/modules). This folder contains a set of
  libraries organized as modules each abstracting a specific functionality.
  These are compile-time libraries with internal functions, they do not serve
  the purpose of organizing the code into runtime (public) libraries. As
  Solidity libraries usually work, the code is assumed to execute via delegate
  calls in the context of the caller contract. _Some of the provided functionaly
  may not be currently used but is kept as part of the code base as it was
  useful in the past and may be useful in the future._
* [/contracts/network/](contracts/network). In this folder we have a simple
  and helpful library to declare static properties such as the current network
  (mainnet, ropsten, etc), well-known useful contract addresses for each
  supported network, as well as some global definitions that are handy for
  debugging during development.

The [/contracts/](contracts) folder contains basically 10 groups of files as
presented below. Their actual functionality is described in the next section.

* **Interface files**, such as [GToken.sol](contracts/GToken.sol),
  [GCToken.sol](contracts/GCToken.sol), and
  [GExchange.sol](contracts/GExchange.sol) that describe the available public
  interface to the smart contracts.
  [GToken.sol](contracts/GToken.sol) is the general interface for the GrowthDeFi
  V1 tokens (refered to as gTokens) and [GCToken.sol](contracts/GCToken.sol) is
  an extension of that interface to decribe the GrowthDeFi V1 tokens based on
  Compound cTokens (and refered to as gcTokens).
  [GExchange.sol](contracts/GExchange.sol) is a simple interface for an external
  contract specialized in token conversion; which allows for the replacement
  and customization of the conversion service provider used by gTokens at any
  given point in time.
* **Abstract contract files** that provide the basis implementation of shared
  functionality for their respective interface. These are basically
  [GTokenBase.sol](contracts/GTokenBase.sol) for gTokens,
  [GCTokenBase.sol](contracts/GCTokenBase.sol) for gcTokens, and
  [GATokenBase.sol](contracts/GATokenBase.sol) for gaTokens.
  Note that gTokens extend the ERC-20 specification and we use the
  [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/v3.2.0)
  library as basis for their implementation. Besides the ERC-20 related
  functionality we also make use of OpenZeppelin's Ownable to guard admin-only
  public functions and ReentrancyGuard to conservatively guard all publicly
  exposed functions against reentrancy.
* **Concrete contract files** that derive from the abstract contract files by
  filling in the specific details purposedly left open. These provide the
  final/leaf contracts in the gTokens hierarchy. The list comprises
  gTokens Type 0 (a.k.a. PMTs) [GTokenType0.sol](contracts/GTokenType0.sol);
  gcTokens implemented in two flavors: Type 1 gcTokens
  [GCTokenType1.sol](contracts/GCTokenType1.sol), and Type 2 gcTokens
  [GCTokenType2.sol](contracts/GCTokenType2.sol); and the gaTokens Type 2
  [GATokenType2.sol](contracts/GATokenType2.sol).
* **Component contracts as (public) libraries** that provide core functionality
  implementation. Besides properly encapsulating the functionality they also
  allow working around the contract size limitations of the EVM.
  These are [GLiquidityPoolManager.sol](contracts/GLiquidityPoolManager.sol)
  for liquidity pool management/handling;
  [GPortfolioReserveManager.sol](contracts/GPortfolioReserveManager.sol) for
  multi token exposure allowing a distribution of the reserve to a list
  of gTokens in a amind-defined percentual allocation (used by Type 0 gTokens);
  [GCLeveragedReserveManager.sol](contracts/GCLeveragedReserveManager.sol) for
  leveraged reserve management/handling where flash loans are used to maintain
  the desired leverage level over lending/borrowing of the reserve of cTokens
  (used by Type 1 gcTokens);
  [GCDelegatedReserveManager.sol](contracts/GCDelegatedReserveManager.sol) for
  delegated reserve management/handling where borrowing is employed to mint
  other gTokens that are used to maintain and grow the cToken reserve
  (used by Type 2 gcTokens);
  [GADelegatedReserveManager.sol](contracts/GADelegatedReserveManager.sol) for
  delegated reserve management/handling where borrowing is employed to mint
  other gTokens that are used to maintain and grow the aToken reserve
  (used by Type 2 gaTokens);
* **A single entrypoint file** [GTokens.sol](contracts/GTokens.sol) that
  succinctly declares all the available gTokens.
* **A public library** [G.sol](contracts/G.sol) that compiles and serves as
  entrypoint to all the relevant functions available under the
  [/modules/](contracts/modules) folder. This library exists mostly to work
  around the EVM limitation of contract sizes, but it also provide a concise
  standardized and neat reference to library code.
* **Two handy pure calculation libraries** that hoist gToken and gcToken
  minting/burning formulas, [GFormulae](contracts/GFormulae.sol) and
  [GCFormulae](contracts/GCFormulae.sol) respectively. These provide a set of
  pure (in the Solidity sense) functions.
* **A contract that helps abstract FlashLoans callbacks**
  [GFlashBorrower.sol](contracts/GFlashBorrower.sol) for both Aave and DyDx.
  This class is used by Type 1 tokens to perform flash loans and efficiently
  maintain the desired leverage level.
* **Two, and possibly more, exchange implementations** deriving from
  [GExchange.sol](contracts/GExchange.sol) to handle token conversion,
  such as [GUniswapV2Exchange.sol](contracts/GUniswapV2Exchange.sol),
  [GSushiswapExchange.sol](contracts/GSushiswapExchange.sol). _Possibly more
  providers or more sophisticated routing maybe be added on the future._
* **The reference implementation of the GRO token** is available on
  [GrowthToken.sol](contracts/GrowthToken.sol).

## High-Level Smart Contract Functionality

This repository implements the first batch of tokens for the GrowthDeFi
platform. These tokens, so called gTokens, are organized in the following
hierarchy:

* gToken
  * gcToken
    * gcToken (Type 1)
      * gcDAI
      * gcUSDC
      * gcUSDT
    * gcToken (Type 2)
      * gcETH
      * gcWBTC
      * gcBAT
      * gcZRX
      * gcUNI
  * gaToken
    * gaToken (Type 2)
      * gacENJ
      * gacKNC
      * gacAAVE
      * gacLINK
      * gacMANA
      * gacREN
      * gacSNX
      * gacYFI

Other gTokens based on other platforms (such as Aave, Curve, etc) will be added
to the hierarchy in the future.

### Basic gToken functionality

A gToken is a token that maintains a reserve, in another token, and provides
its supply. The price of a gToken unit can be derived by the ratio between the
reserve and the supply.

To mint and burn gTokens one must deposit and withdrawal the underlying reserve
token to and from the associated gToken smart contract. Anyone can perform
these operations as long as they provide the required underlying asset amount.

For each of these operations there is a 1% fee deducted from the gToken amount
involved in the operation. The fee is based on the nominal price of gTokens
calculated just before the actual operation takes place.

The fee collected is split twofold: 1) half is immediatelly burned, which is
equivalent to redistributing the underlying associated reserve among all gToken
holds; 2) the other half is provided to a liquidity pool.

Every gToken contract is associated to a Balancer liquidity pool comprised of
50% of GRO and 50% of the given gToken. This liquidity pool is available
publicly for external use and arbitrage and is set up with a trade fee of 10%.

Associated with the liquidity pool there is also some priviledged (admin)
functionality to:

1. Allocate the pool and associate with the gToken contract
2. Burn 0.5% (or the actual burning rate) once per week
3. Set the burning rate, which is initially 0.5%
4. Migrate the pool funds (GRO and gToken balances) to an external address
   with a 7 day grace period

Note that after the liquidity pool is migrated for the first time, the gToken
contract collects a 2% fee on deposits and does not collect any fee for
withdrawals.

Relevant implementation files:

* [GToken.sol](contracts/GToken.sol)
* [GFormulae.sol](contracts/GFormulae.sol)
* [GTokenBase.sol](contracts/GTokenBase.sol)
* [GLiquidityPoolManager.sol](contracts/GLiquidityPoolManager.sol)

### Basic gcToken Type 1 functionality

gcTokens are cTokens based on their Compound counterpart. For instance gcDAI
has as reserve token cDAI.

The gcTokens Type 1 are stable-coin based. They maintain a reserve using their
Compound counterpart which provides yield based on the associated underlying
asset (DAI in case of cDAI) and also allows for the collection of COMP tokens.

The COMP collected is converted to DAI, and used to mint cDAI, as soon as a
minimal amount is reached. The conversion is performed using the associated
exchange contract and is limited to a maximal amount. Both the min/max amounts
and the exchange contract can be modified by the gcToken contract owner.

The gcToken Type 1 contract incorporates the ability to deposit/withdraw
balances directly in DAI handling internally the details of minting cDAI and
redeeming DAI from cDAI.

The main functionality of the gcToken Type 1 contract is leveraging. The
contract incorporates a logic to mint cDAI and use it to borrow DAI. The new
DAI is then used again to mint more cDAI which in turn is used to borrow more
DAI. This cycle is repeaded until we reach the point where the difference
between the total amount of DAI used to mint cDAI and the total of DAI borrowed
is closed to the actual amount of DAI carried by the reserve.

For example, if we have $100 worth of DAI in the reserve, assuming 75%
DAI collateralization ratio from Compound, after 1-cycle, we would have
borrowed $75 worth of DAI and minted $175 worth of cDAI. If we repeat that
process, at each cycle, we get closer and closer to borrowing $300 worth of DAI
and minting $400 worth of cDAI. The reserve becomes the actual difference
between these two amounts and the leverage is maximal.

The proccess of cycling into and out off leverage could be done via loops
using just the liquidity available in the gToken contract. However, we have
optimized the process to avoid loops using a flash loan. We borrow the required
amount of assets to perform the operation and then return it in a single shot.

Note that the actual reserve collateralization ratio used by the gcToken Type 1
contract can be provided by the contract owner and is relative to the maximal
collateralization ratio allowed by Compound. In order to switch off leveraging
one must set this collateralization ratio to 0%.

As a final note, leveraging is used to potentialize gains on the Compound
platform. Due to liquidity mining lending and borrowing from itself may,
at times, result in higher yields.

Relevant implementation files:

* [GCToken.sol](contracts/GCToken.sol)
* [GCFormulae.sol](contracts/GCFormulae.sol)
* [GCTokenBase.sol](contracts/GCTokenBase.sol)
* [GCTokenType1.sol](contracts/GCTokenType1.sol)
* [GCLeveragedReserveManager.sol](contracts/GCLeveragedReserveManager.sol)

### Basic gcToken Type 2 functionality

_Under construction_

Relevant implementation files:

* [GCToken.sol](contracts/GCToken.sol)
* [GCFormulae.sol](contracts/GCFormulae.sol)
* [GCTokenBase.sol](contracts/GCTokenBase.sol)
* [GCTokenType2.sol](contracts/GCTokenType2.sol)
* [GCDelegatedReserveManager.sol](contracts/GCDelegatedReserveManager.sol)

### Basic gaToken Type 2 functionality

_Under construction_

Relevant implementation files:

* [GATokenBase.sol](contracts/GATokenBase.sol)
* [GATokenType2.sol](contracts/GATokenType2.sol)
* [GADelegatedReserveManager.sol](contracts/GADelegatedReserveManager.sol)

## Building, Deploying and Testing

configuring the repository:

    $ npm i

Compiling the smart contracts:

    $ npm run build

Deploying the smart contracts (locally):

    $ ./start-mainnet-fork.sh & npm run deploy

Deploying the smart contracts to mainnet:

    $ npm run deploy:mainnet

Running the unit tests:

    $ ./start-mainnet-fork.sh & npm run test

Running the stress test:

    $ ./start-mainnet-fork.sh & npm run stress-test

