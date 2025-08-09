#!/bin/bash

# ChainlinkOracle Deployment Script for Licredity v1 Oracle
# Usage: ./deploy.sh <CHAIN>
# Example: ./deploy.sh Ethereum
# Example: ./deploy.sh Base

set -e

# Check if required arguments are provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <CHAIN>"
    echo "Available chains: Ethereum, Base, Unichain"
    echo ""
    echo "Examples:"
    echo "  $0 Ethereum"
    echo "  $0 Base"
    echo "  $0 Unichain"
    exit 1
fi

CHAIN=$1

echo "=== ChainlinkOracle Deployment ==="
echo "Chain: $CHAIN"
echo "Timestamp: $(date)"
echo ""

# Load environment variables
if [ ! -f .env ]; then
    echo "Error: .env file not found. Please create one based on .env.example"
    exit 1
fi

source .env

# Set environment variables for the deployment
export CHAIN="$CHAIN"

# Get the RPC URL for the specified chain
RPC_URL_VAR="${CHAIN}_RPC_URL"
RPC_URL=${!RPC_URL_VAR}

if [ -z "$RPC_URL" ]; then
    echo "Error: RPC URL not found for chain $CHAIN"
    echo "Please set ${RPC_URL_VAR} in your .env file"
    exit 1
fi

echo "RPC URL: $RPC_URL"

# Validate required environment variables for ChainlinkOracle deployment
GOVERNOR_VAR="${CHAIN}_GOVERNOR"
LICREDITY_VAR="${CHAIN}_LICREDITY_CORE"

if [ -z "${!GOVERNOR_VAR}" ]; then
    echo "Error: Governor address not found for chain $CHAIN"
    echo "Please set ${GOVERNOR_VAR} in your .env file"
    exit 1
fi

if [ -z "${!LICREDITY_VAR}" ]; then
    echo "Error: Licredity Core address not found for chain $CHAIN"
    echo "Please set ${LICREDITY_VAR} in your .env file"
    exit 1
fi

echo "Governor: ${!GOVERNOR_VAR}"
echo "Licredity Core: ${!LICREDITY_VAR}"

# Check for deployer private key
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not found in .env file"
    exit 1
fi


# Create deployments directory if it doesn't exist
mkdir -p deployments

# Determine which API key to use for verification
API_KEY_VAR="${CHAIN}_SCAN_API_KEY"
API_KEY=${!API_KEY_VAR}
VERIFY_ARGS=""

if [ ! -z "$API_KEY" ]; then
    VERIFY_ARGS="--verify --etherscan-api-key $API_KEY"
    echo "Contract verification enabled for $CHAIN"
else
    echo "Warning: No API key found for $CHAIN verification (${API_KEY_VAR}). Skipping verification."
fi

echo ""
echo "=== Starting Deployment ==="
echo ""

# Deploy the ChainlinkOracle
forge script script/Deploy.s.sol:DeployOracleScript \
    --rpc-url "$RPC_URL" \
    --broadcast \
    $VERIFY_ARGS \
    -vvvv

echo ""
echo "=== Deployment Complete ==="
echo "Check the deployments/ directory for deployment artifacts"
echo ""