# Licredity v1 Oracle

A robust, multi-chain oracle system that provides reliable price feeds for the Licredity DeFi protocol. Built on Chainlink's proven infrastructure with seamless integration into Uniswap v3/v4 ecosystems.

## Overview

The Licredity v1 Oracle serves as the critical price discovery mechanism for the Licredity protocol, combining the reliability of Chainlink price feeds with sophisticated on-chain price tracking and exponential moving average (EMA) calculations. The oracle supports both fungible and non-fungible token valuations across multiple blockchain networks.

## Key Features

### **EMA Price**
We used the following EMA price algorithm to calculate the average price:
$$
\begin{gather}
\text{EMA} = \alpha \cdot \text{pirce} \times (1 - \alpha) \cdot \text{lastPirce} \\
\\
\alpha = e^{\text{power}} \\
\\
\text{power} = \frac{\text{lastUpdateTimeStamp} - \text{block.timestamp}}{600} \\
\end{gather}
$$

Note: To avoid price manipulation, the `price` used here is limited to the range of 1.5625% above and below `lastPrice`

### **Chainlink Integration**
- Leverages Chainlink's decentralized price feeds for maximum reliability
- Configurable staleness protection to ensure data freshness
- Support for multiple base/quote currency pairs

### **Advanced Price Tracking**
- Real-time price updates with EMA smoothing
- Time-weighted price calculations for reduced manipulation risk
- Automatic price feed validation and staleness checks

### **Uniswap Integration**
- Native support for Uniswap v3 and v4 liquidity positions
- Whitelisted pool management for secure position valuation
- Position manager integration for NFT liquidity tracking

## Architecture

```
┌─────────────────┐    ┌──────────────────┐      ┌────────────────────┐
│   Licredity     │◄───┤ ChainlinkOracle  │────► |  Chainlink Feeds   │
│   Protocol      │    │                  │      │                    │
└─────────────────┘    └──────────────────┘      └────────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │ Uniswap Modules  │
                       │ ├─ V3 Module     │
                       │ └─ V4 Module     │
                       └──────────────────┘
```

The oracle system consists of:

- **ChainlinkOracle**: Core oracle contract implementing price discovery and EMA calculations
- **ChainlinkOracleConfigs**: Governance and configuration management
- **Uniswap Modules**: Position valuation for v3/v4 liquidity positions
- **Mathematical Libraries**: Fixed-point arithmetic and feed validation utilities


## Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/) - Ethereum development toolkit
- [Soldeer](https://soldeer.xyz/) - Dependency management

### Installation

```bash
git clone https://github.com/Licredity/licredity-v1-oracle.git
cd licredity-v1-oracle
```

### Build & Test

```bash
# Install dependencies and compile contracts
forge build

# Run comprehensive test suite  
forge test

# Generate coverage report
forge coverage
```

### Environment Setup

Copy `.env.example` to `.env` and configure:

```bash
# Deployment account
PRIVATE_KEY=0x...

# Network configurations (example for Ethereum)
Ethereum_LICREDITY_CORE=0x...
Ethereum_GOVERNOR=0x...
Ethereum_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/...
```

### Deployment

Deploy to any supported network:

```bash
# Dry run deployment
./deploy.sh Ethereum

# Execute deployment
./deploy.sh Ethereum --deploy
```

## Oracle Functionality

### Price Discovery

The oracle provides two primary interfaces for price discovery:

1. **`quotePrice()`** - Returns the current EMA-smoothed price
2. **`quoteFungibles()`** - Values multiple fungible tokens with margin requirements
3. **`quoteNonFungibles()`** - Values Uniswap liquidity positions (NFTs)

### Price Update Mechanism

- Automatic updates triggered on `quoteFungibles()` and `quoteNonFungibles()` calls
- EMA calculation smooths price volatility over configurable time windows
- Chainlink feed staleness validation ensures data integrity

### Configuration Management

Governance-controlled parameters include:
- Asset-specific margin requirement ratios
- Chainlink feed mappings (base/quote pairs)
- Uniswap pool whitelisting
- Maximum staleness thresholds

## Audit

### External Audits
- [**Cyfrin Audits**](/docs/audits/Cyfrin%202025-09-01.pdf)

## Contributing

We welcome contributions to improve the Licredity Oracle system. Please:

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests for new functionality
4. Follow existing code style and documentation standards
5. Submit a pull request with detailed description

## License

This project is licensed under the [MIT](/docs/licenses/MIT_LICENSE).