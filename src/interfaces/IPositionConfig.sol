// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Fungible} from "src/types/Fungible.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {IUniswapV4PositionManager} from "./external/IUniswapV4PositionManager.sol";
import {AggregatorV3Interface} from "./external/AggregatorV3Interface.sol";
import {IPoolManager as IUniswapV4PoolManager} from "v4-core/interfaces/IPoolManager.sol";

interface IPositionConfig {
    error NotGovernor();
    error NotExistFungibleFeedConfig();
    error NotExistNonFungiblePoolIdWhitelist();

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

    /// @notice Provides multiple oracle configurations for asset to debt token price calculations
    /// @param asset The address of the asset
    /// @param baseFeed Base feed. Pass address zero if the price = 1
    /// @param quoteFeed Quote feed. Pass address zero if the price = 1
    /// @dev The implementation automatically multiplies the base fee calculation result by the debtToken/token price.
    function updateFungibleFeedsConfig(
        Fungible asset,
        uint24 mrrPips,
        AggregatorV3Interface baseFeed,
        AggregatorV3Interface quoteFeed
    ) external;

    /// @notice Delete the oracle configuration
    /// @param asset The address of the asset
    function deleteFungibleFeedsConfig(Fungible asset) external;

    /// @notice Initialize the Uniswap V4 position module
    /// @param poolManager The Uniswap V4 pool manager
    /// @param positionManager The Uniswap V4 position manager
    function initUniswapV4PositionModule(IUniswapV4PoolManager poolManager, IUniswapV4PositionManager positionManager)
        external;
}
