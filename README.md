# 🏛️ Decentralized Stablecoin Engine (DSCEngine)

A minimalistic, governance-free stablecoin protocol inspired by MakerDAO’s DAI system. This system mints a decentralized, algorithmically stabilized coin (DSC) using exogenous crypto collateral such as wETH and wBTC.

## 🧠 Overview

The `DSCEngine` is a smart contract system that allows users to:

- Deposit crypto collateral (e.g., wETH, wBTC)
- Mint a USD-pegged stablecoin (DSC)
- Burn DSC to reclaim collateral
- Be liquidated if undercollateralized

### Key Properties

- ❌ **No governance**
- 💸 **No fees**
- 🛡️ **Overcollateralized** (100%+)
- 🔒 **Reentrancy-safe** via OpenZeppelin
- ⚖️ **Maintains peg via economic incentives & liquidation**

---

## 🧱 Architecture

### Core Components

- `DSCEngine`: Main logic for collateral management, minting, burning, and liquidation.
- `DecentralizedStableCoin`: ERC20-compliant token that represents the DSC.
- `OracleLib`: Chainlink-integrated oracle utility for secure price feeds.

### Features

| Feature                | Description                                                               |
| ---------------------- | ------------------------------------------------------------------------- |
| Collateralized Minting | Mint DSC by depositing approved collateral.                               |
| Health Factor Checks   | Prevents minting or withdrawing that would break safety thresholds.       |
| Liquidation Engine     | Enables liquidation of undercollateralized positions with a bonus reward. |
| Oracle Integration     | Uses Chainlink price feeds with freshness checks.                         |

---

## ⚙️ Contract Details

- **Collateral Tokens:** wETH, wBTC (configurable)
- **Liquidation Threshold:** 50%
- **Health Factor Minimum:** 1.0 (1 \* 1e18)
- **Liquidation Bonus:** 10%

---

## 🔐 Security Considerations

- Reentrancy protection via OpenZeppelin's `ReentrancyGuard`
- Input validations (e.g. zero-value checks, approved tokens only)
- CEI pattern (Checks, Effects, Interactions) followed where possible
- Price oracle data freshness checks via `OracleLib`

---

## 🚀 Getting Started

### Prerequisites

- Foundry

### Install Dependencies

```bash
forge install
```
