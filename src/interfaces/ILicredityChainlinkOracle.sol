// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";
import {Fungible} from "../types/Fungible.sol";
import {NonFungible} from "../types/NonFungible.sol";

interface ILicredityChainlinkOracle {
    /// @notice Event emitted when the new feeds are set
    /// @param asset The address of the asset
    /// @param baseFeed Base feed
    /// @param quoteFeed Quote feed
    event FeedsUpdated(Fungible indexed asset, AggregatorV3Interface baseFeed, AggregatorV3Interface quoteFeed);

    /// @notice Function to get the value, in debt token terms, of some amount of fungible
    /// @param fungible The fungible to quote
    /// @param amount The amount of fungible to quote
    /// @return value The value of the fungible in debt token terms
    function quoteFungible(Fungible fungible, uint256 amount) external returns (uint256 value);

    /// @notice Function to get the value, in debt token terms, of a non-fungible
    /// @param nonFungible The non-fungible to quote
    /// @return value The value of the non-fungible in debt token terms
    function quoteNonFungible(NonFungible nonFungible) external returns (uint256 value);

    /// @notice Update the price of debt token based on EMA using the price from beforeSwap Hook
    function update() external;

    /// @notice Provides multiple oracle configurations for asset to debt token price calculations
    /// @param asset The address of the asset
    /// @param baseFeed Base feed. Pass address zero if the price = 1
    /// @param quoteFeed Quote feed. Pass address zero if the price = 1
    /// @dev The implementation automatically multiplies the base fee calculation result by the token/debtToken price.
    function updateFeedsConfig(Fungible asset, AggregatorV3Interface baseFeed, AggregatorV3Interface quoteFeed)
        external;

    /// @notice Delete the oracle configuration
    /// @param asset The address of the asset
    function deleteFeedsConfig(Fungible asset) external;
}
