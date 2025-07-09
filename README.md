# Licredity Oracle v1

A sophisticated oracle system for the Licredity protocol that provides price information for fungible and non-fungible tokens by integrating Chainlink price feeds with Uniswap V4 pool data.

## Overview

The Licredity Oracle combines multiple price sources, via Chainlink, to provide accurate and manipulation-resistant pricing for DeFi applications. It uses an exponential moving average (EMA) with price clamping to smooth out volatility while maintaining responsiveness to market changes.

### Key Features

- **Chainlink Integration**: Leverages Chainlink's decentralized price feeds for reliable external price data
- **Uniswap V4 Support**: Integrates with Uniswap V4 pools for LP position valuation
- **Price Smoothing**: Uses EMA with 10-minute half-life to reduce volatility impact
- **Manipulation Protection**: Implements price clamping (max 1.5625% change per block)
- **Modular Architecture**: Extensible design for supporting additional protocols
- **Governance Controls**: Configurable parameters with governor-controlled access

### EMA Price

We used the following EMA price algorithm to calculate the average price:

$$
\begin{gather}
\alpha = e^{\text{power}} \\
\text{power} = \frac{\text{lastUpdateTimeStamp} - \text{block.timestamp}}{600} \\
\text{EMA} = \alpha \cdot \text{pirce} \times (1 - \alpha) \cdot \text{lastPirce}
\end{gather}
$$

Note: To avoid price manipulation, the `price` used here is limited to the range of 0.015625 above and below `lastPrice`

## Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                    ChainlinkOracle                          │
├─────────────────────────────────────────────────────────────┤
│  • Main oracle contract implementing IOracle interface      │
│  • EMA price calculation with manipulation protection       │
│  • Fungible and non-fungible token valuation                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                ChainlinkOracleConfigs                       │
├─────────────────────────────────────────────────────────────┤
│  • Configuration management for fungible tokens             │
│  • Chainlink feed management                                │
│  • Uniswap V4 module integration                            │
│  • Governor-controlled access                               │
└─────────────────────────────────────────────────────────────┘
```

### Libraries

- **FixedPointMath**: High-precision mathematical operations including exponential functions
- **ChainlinkFeedLibrary**: Chainlink price feed interaction utilities
- **UniswapV4Module**: Uniswap V4 position valuation and pool management

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [UV](https://docs.astral.sh/uv/) (for Python scripts)

### Installation

1. Clone the repository:

```bash
git clone <repository-url>
cd licredity-v1-oracle
```

2. Install dependencies:

```bash
forge soldeer install
```

3. Set up Python environment (optional, for testing scripts):

```bash
uv sync
```

### Building

```bash
forge build
```

### Testing

Run all tests:

```bash
forge test
```

Run specific test file:

```bash
forge test --match-path test/ChainlinkOracleTest.sol
```

Run tests with detailed output:

```bash
forge test -vvv
```

### Formatting

```bash
forge fmt
```

## Configuration

### Environment Variables

Set up your environment variables in `.env`:

```bash
ETH_RPC_URL=https://your-ethereum-rpc-url
```

### Foundry Configuration

The project uses `foundry.toml` for configuration with the following key settings:

- **Solidity Version**: 0.8.30
- **Optimizer**: Enabled with `via_ir = true`
- **FFI**: Enabled for Python script integration
- **Dependencies**: Managed via Soldeer

## Usage

### Deploying the Oracle

```solidity
// Deploy the oracle with Licredity address and governor
ChainlinkOracle oracle = new ChainlinkOracle(
    address(licredityProtocol),
    address(governor)
);

// Initialize Uniswap V4 module
oracle.initializeUniswapV4Module(
    address(poolManager),
    address(positionManager)
);
```

### Configuring Fungible Tokens

```solidity
// Configure a fungible token with Chainlink feeds
oracle.setFungibleConfig(
    Fungible.wrap(tokenAddress),
    100000, // 10% margin requirement (in pips)
    AggregatorV3Interface(baseFeedAddress),
    AggregatorV3Interface(quoteFeedAddress)
);
```

### Getting Price Quotes

```solidity
// Get current EMA price
uint256 price = oracle.quotePrice();

// Quote multiple fungible tokens
Fungible[] memory tokens = new Fungible[](2);
uint256[] memory amounts = new uint256[](2);
// ... populate arrays ...

(uint256 value, uint256 marginRequirement) = oracle.quoteFungibles(tokens, amounts);
```

### Uniswap V4 Position Valuation

```solidity
// Whitelist a Uniswap V4 pool
oracle.setUniswapV4Pool(poolId, true);

// Quote non-fungible tokens (LP positions)
NonFungible[] memory positions = new NonFungible[](1);
// ... populate positions ...

(uint256 value, uint256 marginRequirement) = oracle.quoteNonFungibles(positions);
```

## Price Update Mechanism

The oracle implements a sophisticated price update system:

1. **Pool Price Fetching**: Gets `sqrtPriceX96` from Uniswap V4 pool
2. **Price Clamping**: Limits price movement to 1.5625% per block
3. **EMA Calculation**: Applies exponential moving average with 10-minute half-life
4. **Alpha Calculation**: `alpha = e^(-(currentTime - lastUpdateTime) / 600)`
5. **Price Smoothing**: `newEmaPrice = alpha * currentPrice + (1 - alpha) * lastPrice`

## Testing

### Test Structure

- **Unit Tests**: Individual component testing in `test/`
- **Integration Tests**: Full system testing scenarios
- **Python Scripts**: Mathematical validation in `test/python-scripts/`
- **Fuzz Testing**: Property-based testing for edge cases

### Key Test Files

- `ChainlinkOracleTest.sol`: Core oracle functionality tests
- `FixedPointMath.t.sol`: Mathematical library tests
- `UniswapV4Position.t.sol`: Position valuation tests
- `ema_update.py`: Python script for EMA validation

### Running Specific Tests

```bash
# Test oracle price updates
forge test --match-test test_oracleUpdate

# Test fungible token pricing
forge test --match-test test_quoteFungible

# Fuzz testing
forge test --match-test test_oracleUpdate_fuzz
```

## Security Considerations

⚠️ **Important Security Notes:**

1. **Chainlink Feed Validation**: Ensure proper staleness checks are implemented
2. **Governor Security**: Use multi-sig or timelock for governance operations
3. **Price Manipulation**: Monitor for sustained manipulation attempts
4. **Input Validation**: Validate all external inputs and array sizes
5. **Circuit Breakers**: Implement emergency pause mechanisms

### Security Best Practices

- Always validate Chainlink feed responses
- Use timelock for critical configuration changes
- Monitor oracle price deviations
- Implement proper access controls
- Regular security audits

## Governance

The oracle system uses a governor-controlled configuration model:

### Governor Functions

- `updateGovernor(address)`: Transfer governance to new address
- `setFungibleConfig(...)`: Configure fungible token parameters
- `deleteFungibleConfig(...)`: Remove fungible token configuration
- `initializeUniswapV4Module(...)`: Initialize Uniswap V4 integration
- `setUniswapV4Pool(...)`: Whitelist/blacklist pools

### Access Control

All configuration changes require governor approval. Consider using:

- Multi-signature wallets
- Timelock contracts
- DAO governance systems

## Development

### Adding New Modules

To add support for new protocols:

1. Create a new module in `src/modules/`
2. Implement the required interface
3. Update the oracle to dispatch to the new module
4. Add corresponding tests

### Mathematical Operations

The system uses fixed-point arithmetic for precision:

- Prices are stored in X96 format
- EMA calculations use signed integers
- Margin requirements use pips (1 pip = 0.0001%)

## API Reference

### Core Functions

#### `quotePrice() → uint256`

Returns the current EMA price.

#### `quoteFungibles(Fungible[], uint256[]) → (uint256, uint256)`

Returns total value and margin requirement for fungible tokens.

#### `quoteNonFungibles(NonFungible[]) → (uint256, uint256)`

Returns total value and margin requirement for non-fungible tokens.

#### `update()`

Updates the oracle price from the underlying Uniswap V4 pool.

### Configuration Functions

#### `setFungibleConfig(Fungible, uint24, AggregatorV3Interface, AggregatorV3Interface)`

Configures a fungible token with margin requirements and price feeds.

#### `setUniswapV4Pool(PoolId, bool)`

Sets the whitelist status of a Uniswap V4 pool.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

### Code Style

- Follow the existing Solidity style guidelines
- Use meaningful variable names
- Add comprehensive comments
- Include proper error handling

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This software is provided as-is without any warranties. Use at your own risk. Always conduct thorough testing and auditing before deploying to production.

---
