# Deployment Guide

This guide explains how to deploy the ChainlinkOracle contract for the Licredity v1 Oracle system.

## Prerequisites

1. **Foundry**: Ensure you have Foundry installed and updated
2. **Environment Setup**: Copy `.env.example` to `.env` and configure all required variables
3. **Deployed Licredity**: The main Licredity protocol contract must be deployed first
4. **Network Access**: RPC access to your target network
5. **Deployer Account**: An account with sufficient ETH for deployment

## Configuration

### 1. Environment Variables

Copy the example configuration:
```bash
cp .env.example .env
```

### 2. Required Variables Per Network

For each network you want to deploy to, configure these variables in `.env`:

#### Ethereum Mainnet
```bash
Ethereum_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
Ethereum_SCAN_API_KEY=your-etherscan-api-key
Ethereum_LICREDITY_CORE=0x...    # Address of deployed Licredity contract
Ethereum_GOVERNOR=0x...          # Governance multisig address
```

#### Base
```bash
Base_RPC_URL=https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY
Base_SCAN_API_KEY=your-basescan-api-key
Base_LICREDITY_CORE=0x...        # Address of deployed Licredity contract
Base_GOVERNOR=0x...              # Governance multisig address
```

#### Unichain
```bash
Unichain_RPC_URL=https://unichain-mainnet.g.alchemy.com/v2/YOUR_API_KEY
Unichain_SCAN_API_KEY=your-uniscan-api-key
Unichain_LICREDITY_CORE=0x...    # Address of deployed Licredity contract
Unichain_GOVERNOR=0x...          # Governance multisig address
```

### 3. Deployer Configuration

```bash
PRIVATE_KEY=0x...                # Private key of deployment account
```

## Deployment Process

### 1. Verify Configuration

Make sure all required environment variables are set:
```bash
# Check your configuration
cat .env | grep -E "(RPC_URL|LICREDITY_CORE|GOVERNOR|PRIVATE_KEY)"
```

### 2. Deploy ChainlinkOracle

Deploy to your chosen network:

```bash
# Deploy to Ethereum
./deploy.sh Ethereum

# Deploy to Base
./deploy.sh Base

# Deploy to Unichain
./deploy.sh Unichain
```

### 3. Verify Deployment

The deployment script will:
- ✅ Validate all environment variables  
- ✅ Deploy the ChainlinkOracle contract
- ✅ Automatically verify on block explorer (if API key provided)
- ✅ Save deployment artifacts to `deployments/` directory

## Post-Deployment

### 1. Deployment Artifacts

After successful deployment, check the generated artifact file:
```bash
# Example for Ethereum deployment
cat deployments/Ethereum_ChainlinkOracle.env
```

The artifact contains:
- Contract address
- Licredity contract address
- Governor address

### 2. Verification

If automatic verification failed, you can manually verify:
```bash
forge verify-contract \
  --chain-id CHAIN_ID \
  --etherscan-api-key YOUR_API_KEY \
  CONTRACT_ADDRESS \
  src/ChainlinkOracle.sol:ChainlinkOracle \
  --constructor-args $(cast abi-encode "constructor(address,address)" LICREDITY_ADDRESS GOVERNOR_ADDRESS)
```

### 3. Configuration

After deployment, the ChainlinkOracle will need to be configured with:
- Fungible token configurations (margin requirements, price feeds)
- Module registrations (for non-fungible token support)
- Price feed addresses

This is typically done through governance proposals.

## Troubleshooting

### Common Issues

1. **"Governor address cannot be zero"**
   - Check that `{CHAIN}_GOVERNOR` is set in your `.env` file

2. **"Licredity address cannot be zero"**
   - Check that `{CHAIN}_LICREDITY_CORE` is set in your `.env` file

3. **"RPC URL not found"**
   - Check that `{CHAIN}_RPC_URL` is set in your `.env` file

4. **Verification failures**
   - Check that your scan API key is valid
   - Manual verification may be needed for some networks

### Network-Specific Notes

- **Ethereum**: High gas fees, consider deploying during low congestion
- **Base**: Generally lower fees, good for testing
- **Unichain**: Check current RPC endpoints and block explorer support

## Security Considerations

1. **Private Key Security**: Never commit `.env` file to version control
2. **Governor Address**: Ensure governor address is correct and controlled by appropriate multisig
3. **Verification**: Always verify contract source code on block explorers
4. **Testing**: Test deployments on testnets before mainnet

## Example Deployment Flow

```bash
# 1. Setup environment
cp .env.example .env
# Edit .env with your values

# 2. Verify configuration
cat .env | grep Ethereum

# 3. Deploy
./deploy.sh Ethereum

# 4. Check deployment
cat deployments/Ethereum_ChainlinkOracle.env
```

## Support

For deployment issues:
1. Check this documentation
2. Review the deployment logs
3. Verify all environment variables
4. Test with a testnet deployment first