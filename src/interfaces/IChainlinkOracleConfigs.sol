// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {PoolId} from "@uniswap-v4-core/types/PoolId.sol";
import {AggregatorV3Interface} from "./external/AggregatorV3Interface.sol";

/// @title IChainlinkOracleConfigs
/// @notice Interface for Chainlink oracle configurations
interface IChainlinkOracleConfigs {
    /// @notice Emitted when the governor is updated
    /// @param newGovernor The new governor
    event UpdateGovernor(address indexed newGovernor);

    /// @notice Emitted when the maximum staleness is updated
    /// @param newMaxStaleness The new maximum staleness in seconds
    /// @dev This is the maximum time a Chainlink feed can be stale before it is
    event UpdateMaxStaleness(uint256 newMaxStaleness);

    /// @notice Emitted when the configuration for a fungible is set
    /// @param fungible The fungible
    /// @param mrrPips The margin requirement ratio in pips
    /// @param scaleFactor The scale factor
    /// @param baseFeed Base feed
    /// @param quoteFeed Quote feed
    event SetFungibleConfig(
        Fungible indexed fungible,
        uint24 mrrPips,
        uint256 scaleFactor,
        AggregatorV3Interface baseFeed,
        AggregatorV3Interface quoteFeed
    );

    /// @notice Emitted when the configuration for a fungible is deleted
    /// @param fungible The fungible
    event DeleteFungibleConfig(Fungible indexed fungible);

    /// @notice Emitted when the Uniswap V4 module is initialized
    /// @param poolManager The pool manager
    /// @param positionManager The position manager
    event InitializeUniswapV4Module(address indexed poolManager, address indexed positionManager);

    /// @notice Emitted when a Uniswap V4 pool is whitelisted or unwhitelisted
    /// @param poolId The pool ID
    /// @param isWhitelisted Whether the pool is whitelisted
    event SetUniswapV4Pool(PoolId indexed poolId, bool isWhitelisted);

    /// @notice Emitted when the Uniswap V3 module is initialized
    /// @param poolFactory The pool factory
    /// @param positionManager The position manager
    event InitializeUniswapV3Module(address indexed poolFactory, address indexed positionManager);

    /// @notice Emitted when a Uniswap V3 pool is whitelisted or unwhitelisted
    /// @param pool The pool address
    /// @param isWhitelisted Whether the pool is whitelisted
    event SetUniswapV3Pool(address indexed pool, bool isWhitelisted);

    /// @notice Updates the governor
    /// @param newGovernor The new governor
    /// @dev Can only be called by the governor
    function updateGovernor(address newGovernor) external;

    /// @notice Sets the configuration for a fungible
    /// @param fungible The fungible to configure for
    /// @param mrrPips The fungible's margin requirement ratio in pips
    /// @param baseFeed The base feed for the fungible
    /// @param quoteFeed The quote feed for the fungible
    /// @dev Can only be called by the governor
    function setFungibleConfig(
        Fungible fungible,
        uint24 mrrPips,
        AggregatorV3Interface baseFeed,
        AggregatorV3Interface quoteFeed
    ) external;

    /// @notice Deletes the configuration for a fungible
    /// @param fungible The fungible to delete the configuration for
    /// @dev Can only be called by the governor
    function deleteFungibleConfig(Fungible fungible) external;

    /// @notice Initializes the Uniswap V4 module
    /// @param poolManager The pool manager
    /// @param positionManager The position manager
    /// @dev Can only be called by the governor
    function initializeUniswapV4Module(address poolManager, address positionManager) external;

    /// @notice Sets the whitelisted status of a Uniswap V4 pool
    /// @param poolId The pool ID
    /// @param isWhitelisted Whether the pool is whitelisted
    function setUniswapV4Pool(PoolId poolId, bool isWhitelisted) external;

    /// @notice Initializes the Uniswap V3 module
    /// @param poolFactory The pool factory
    /// @param positionManager The position manager
    /// @dev Can only be called by the governor
    function initializeUniswapV3Module(address poolFactory, address positionManager) external;

    /// @notice Sets the whitelisted status of a Uniswap V3 pool
    /// @param pool The pool address
    /// @param isWhitelisted Whether the pool is whitelisted
    function setUniswapV3Pool(address pool, bool isWhitelisted) external;
}
