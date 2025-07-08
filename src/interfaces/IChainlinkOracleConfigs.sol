// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {PoolId} from "@uniswap-v4-core/types/PoolId.sol";
import {AggregatorV3Interface} from "./external/AggregatorV3Interface.sol";

/// @title IChainlinkOracleConfigs
/// @notice Interface for Chainlink oracle configurations
interface IChainlinkOracleConfigs {
    error NotGovernor();
    error NotExistFungibleFeedConfig();

    /// @notice Event emitted when the new governor is set
    /// @param newGovernor The address of the new governor
    event UpdateGovernor(address indexed newGovernor);

    /// @notice Event emitted when the new feeds are set
    /// @param asset The address of the asset
    /// @param baseFeed Base feed
    /// @param quoteFeed Quote feed
    event FeedsUpdate(
        Fungible indexed asset, uint24 mrrPips, AggregatorV3Interface baseFeed, AggregatorV3Interface quoteFeed
    );

    /// @notice Event emitted when the old feeds are deleted
    /// @param asset The address of the asset
    event FeedsDelete(Fungible indexed asset);

    /// @notice Event emitted when the pool ID whitelist is updated
    /// @param poolId The pool ID
    /// @param enabled Whether the pool ID is whitelisted
    event UniswapV4WhitelistUpdated(PoolId indexed poolId, bool enabled);
}
