// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";

interface ILicredityChainlinkOracle {
    /// @notice Event emitted when the new feeds are set
    /// @param asset The address of the asset
    /// @param baseFeed Base feed
    /// @param quoteFeed Quote feed
    event FeedsUpdated(address indexed asset, AggregatorV3Interface baseFeed, AggregatorV3Interface quoteFeed);

    /// @notice Returns the number of debt tokens that can be exchanged for the assets
    /// @param asset The address of the asset
    /// @param amount The amount of the asset
    /// @return debtTokenAmount The number of debt tokens
    function peek(address asset, uint256 amount) external view returns (uint256 debtTokenAmount);

    /// @notice Update the price of debt token based on EMA using the price from beforeSwap Hook
    /// @param sqrtPriceX96 The sqrt price of the token/debtToken
    function updateDebtTokenPrice(uint160 sqrtPriceX96) external;

    /// @notice Provides multiple oracle configurations for asset to debt token price calculations
    /// @param asset The address of the asset
    /// @param baseFeed Base feed. Pass address zero if the price = 1
    /// @param quoteFeed Quote feed. Pass address zero if the price = 1
    /// @dev The implementation automatically multiplies the base fee calculation result by the token/debtToken price.
    function updateFeeds(address asset, AggregatorV3Interface baseFeed, AggregatorV3Interface quoteFeed) external;
}
