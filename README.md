# DeFi Portfolio Manager Smart Contract

![Stacks Blockchain](https://img.shields.io/badge/Blockchain-Stacks-5546ff)

A sophisticated decentralized portfolio management system enabling multi-token portfolio creation, allocation management, and automated rebalancing on the Stacks blockchain.

## Overview

This SIP-010 compliant smart contract implements a non-custodial portfolio management protocol with:

- Multi-asset portfolio creation
- Dynamic allocation controls
- Time-based rebalancing triggers
- Portfolio performance tracking
- Protocol-level fee structure

## Features

### Core Capabilities

- NFT-style portfolio management with unique IDs
- Threshold-based automatic rebalancing (24h intervals)
- Percentage-based allocations (basis points precision)
- Real-time portfolio valuation tracking
- Non-custodial asset management

### Advanced Functionality

- Multi-token support (max 10 assets/portfolio)
- Portfolio ownership verification
- Allocation percentage validation
- User portfolio indexing
- Protocol administration controls

## Technical Specifications

### Data Architecture

```clarity
;; Portfolio Metadata
struct Portfolio {
    owner: principal,
    created-at: uint,
    last-rebalanced: uint,
    total-value: uint,  // 1e8 precision
    active: bool,
    token-count: uint
}

;; Asset Allocation Structure
struct PortfolioAsset {
    target-percentage: uint,  // 0-10000 (0-100%)
    current-amount: uint,     // Token quantity
    token-address: principal  // SIP-010 contract
}
```

### System Constants

| Constant                   | Value  | Description               |
| -------------------------- | ------ | ------------------------- |
| `MAX-TOKENS-PER-PORTFOLIO` | 10     | Maximum supported assets  |
| `BASIS-POINTS`             | 10,000 | 100% allocation precision |
| `PROTOCOL-FEE`             | 25     | 0.25% fee (basis points)  |

## Contract Interface

### Key Functions

#### `create-portfolio`

```clarity
(create-portfolio (initial-tokens (list 10 principal)) (percentages (list 10 uint)))
```

- Creates new portfolio with initial token allocations
- Parameters:
  - `initial-tokens`: List of SIP-010 token contracts
  - `percentages`: Allocation percentages in basis points
- Returns: `uint` portfolio ID

#### `rebalance-portfolio`

```clarity
(rebalance-portfolio (portfolio-id uint))
```

- Executes portfolio rebalancing
- Requirements:
  - 24h cooldown since last rebalance
  - Valid portfolio ownership
- Returns: `bool` success status

#### `update-portfolio-allocation`

```clarity
(update-portfolio-allocation (portfolio-id uint) (token-id uint) (new-percentage uint))
```

- Modifies target allocation for specific asset
- Parameters:
  - `token-id`: Index in portfolio's token list
  - `new-percentage`: Updated allocation (0-10000)

### View Functions

#### `get-portfolio`

```clarity
(get-portfolio (portfolio-id uint))
```

Returns complete portfolio metadata

#### `calculate-rebalance-amounts`

```clarity
(calculate-rebalance-amounts (portfolio-id uint))
```

Returns rebalancing status and total portfolio value

## Error Reference

| Code | Description                   |
| ---- | ----------------------------- |
| u100 | Unauthorized access attempt   |
| u101 | Invalid portfolio ID          |
| u102 | Insufficient token balance    |
| u103 | Invalid token contract        |
| u104 | Rebalancing failure           |
| u105 | Duplicate portfolio ID        |
| u106 | Invalid percentage allocation |
| u107 | Maximum tokens exceeded       |
| u108 | Parameter length mismatch     |

## Administration

### Protocol Ownership

```clarity
(initialize (new-owner principal))
```

- Transfers protocol ownership
- Restricted to current owner
- Single-use function

## Security Model

### Safety Mechanisms

1. Ownership verification for all write operations
2. Allocation percentage validation (0-10000 BPs)
3. Portfolio activation status checks
4. Parameter length matching enforcement
5. Token ID boundary validation

### Fee Structure

- 0.25% protocol fee on portfolio operations
- Fees calculated in basis points (1 BP = 0.01%)
- Fee destination: Protocol owner address

## Limitations & Considerations

1. Rebalancing requires manual trigger (no automation)
2. USD valuations not natively tracked
3. Cross-chain assets not supported
4. Protocol fee implementation pending
5. Price oracle integration needed

## Development Roadmap

- [ ] Automated rebalancing implementation
- [ ] Protocol fee collection system
- [ ] Portfolio performance analytics
- [ ] Price oracle integration
- [ ] Cross-chain asset support
