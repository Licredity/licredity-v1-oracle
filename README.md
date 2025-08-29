# Licredity v1 Oracle

A sophisticated oracle implementation for the Licredity protocol that provides reliable price feeds and asset valuation services. This oracle integrates Chainlink price feeds with Uniswap pool data to deliver accurate, manipulation-resistant pricing for both fungible and non-fungible tokens.

## Overview

The Licredity v1 Oracle serves as the pricing backbone for the Licredity lending protocol, offering:

- **Exponential Moving Average (EMA) Pricing**: Smooth price updates with built-in volatility dampening
- **Multi-Asset Support**: Valuation for fungible tokens and Uniswap LP positions
- **Chainlink Integration**: Reliable external price feeds with staleness protection
- **Uniswap Integration**: Support for both v3 and v4 position valuation
- **Governance Controls**: Secure configuration management with two-step governance transfers

### EMA Price

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

## Key Features

### 🏛️ **Robust Price Oracle**

- EMA-based price calculation with 600-second decay factor
- Price movement capping (1.5625% per block) to prevent manipulation
- Real-time updates from Uniswap v4 pools
- Chainlink feed integration for external price data

### 🔧 **Modular Architecture**

- **UniswapV3Module**: Valuation of Uniswap v3 LP positions
- **UniswapV4Module**: Valuation of Uniswap v4 LP positions
- **ChainlinkFeedLibrary**: Standardized price feed interactions
- **FixedPointMath**: High-precision mathematical operations

### 🛡️ **Security & Governance**

- Two-step governance pattern for secure admin transfers
- Assembly-optimized contracts for gas efficiency
- Comprehensive access controls and validation
- Whitelisted pool system for position modules

### 📊 **Asset Valuation**

- Fungible token pricing with margin requirement calculations
- Non-fungible position valuation through specialized modules
- Multi-decimal precision handling
- Configurable risk parameters per asset

## Architecture

```
ChainlinkOracle (Main Contract)
├── ChainlinkOracleConfigs (Configuration Management)
├── Libraries/
│   ├── ChainlinkFeedLibrary (Feed Interactions)
│   └── FixedPointMath (Mathematical Operations)
└── Modules/
    ├── UniswapV3Module (v3 Position Valuation)
    └── UniswapV4Module (v4 Position Valuation)
```

## Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Node.js and npm (for Python scripts)
- Access to RPC endpoints for target networks

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd licredity-v1-oracle

# Install dependencies
forge soldeer install

# Build contracts
forge build
```

### Testing

```bash
# Run all tests
forge test

# Run with detailed output
forge test -vv

# Run specific test contract
forge test --match-contract ChainlinkOracleTest

# Generate gas report
forge test --gas-report
```

### Deployment

1. Create a `.env` file with your configuration:

```bash
# Deployer Configuration
PRIVATE_KEY=your_private_key_here

# Network Configuration
Ethereum_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR-API-KEY
Base_RPC_URL=https://base-mainnet.g.alchemy.com/v2/YOUR-API-KEY

# Contract Addresses
Ethereum_GOVERNOR=0x...
Ethereum_LICREDITY_CORE=0x...
Base_GOVERNOR=0x...
Base_LICREDITY_CORE=0x...
```

2. Deploy to your target network:

```bash
# Dry run deployment
./deploy.sh Ethereum

# Actual deployment
./deploy.sh Ethereum --deploy
```

## Configuration

### Fungible Token Setup

Configure supported tokens through the governance interface:

```solidity
// Set configuration for a new fungible token
oracle.setFungibleConfig(
    fungible,           // Token contract
    mrrPips,           // Margin requirement ratio (in pips)
    baseFeed,          // Chainlink price feed for base asset
    quoteFeed          // Chainlink price feed for quote asset
);
```

### Uniswap Module Setup

Initialize and configure Uniswap modules:

```solidity
// Initialize Uniswap v4 module
oracle.initializeUniswapV4Module(positionManagerAddress);

// Whitelist a pool for v4 positions
oracle.setUniswapV4Pool(poolId, true);

// Initialize Uniswap v3 module
oracle.initializeUniswapV3Module(nonfungiblePositionManagerAddress);

// Whitelist a pool for v3 positions
oracle.setUniswapV3Pool(poolAddress, true);
```

## Usage Examples

### Price Queries

```solidity
// Get current EMA price
uint256 price = oracle.quotePrice();

// Value multiple fungible tokens
Fungible[] memory tokens = [token1, token2];
uint256[] memory amounts = [amount1, amount2];
(uint256 totalValue, uint256 marginRequirement) = oracle.quoteFungibles(tokens, amounts);

// Value Uniswap positions
NonFungible[] memory positions = [position1, position2];
(uint256 totalValue, uint256 marginRequirement) = oracle.quoteNonFungibles(positions);
```

### Oracle Updates

```solidity
// Manually trigger price update (also happens automatically during quotes)
oracle.update();
```

## Governance

The oracle uses a secure two-step governance pattern:

```solidity
// Step 1: Current governor appoints next governor
oracle.appointNextGovernor(newGovernorAddress);

// Step 2: New governor confirms the transfer
oracle.confirmNextGovernor(); // Must be called by new governor
```

## Network Support

The oracle is designed for multi-chain deployment and currently supports:

- **Ethereum Mainnet**
- **Base**
- **Unichain** (upcoming)

Each network requires specific configuration for:

- Fungible and non-fungible parameters
- Chainlink price feeds
- Uniswap pool contracts
- Licredity core integration

## Security Considerations

- **Price Manipulation Protection**: EMA smoothing and movement caps prevent sudden price shocks
- **Feed Staleness Protection**: Automatic rejection of outdated Chainlink data
- **Access Controls**: Comprehensive permission system for administrative functions
- **Assembly Optimization**: Gas-efficient implementations with proper safety checks

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and add tests
4. Ensure all tests pass (`forge test`)
5. Format your code (`forge fmt`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## Testing

The project includes comprehensive tests covering:

- **Unit Tests**: Individual contract functionality
- **Integration Tests**: Cross-module interactions
- **Mathematical Verification**: EMA calculations using Python FFI
- **Governance Tests**: Permission and access control validation
- **Mock Contracts**: Isolated testing environments

Run specific test categories:

```bash
# Test oracle pricing logic
forge test --match-path test/ChainlinkOracleTest.sol

# Test mathematical libraries
forge test --match-path test/libraries/

# Test Uniswap modules
forge test --match-path test/modules/
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
