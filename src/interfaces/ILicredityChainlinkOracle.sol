// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";
import {Fungible} from "../types/Fungible.sol";
import {NonFungible} from "../types/NonFungible.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

interface ILicredityChainlinkOracle {
    /// @notice Event emitted when the new feeds are set
    /// @param asset The address of the asset
    /// @param baseFeed Base feed
    /// @param quoteFeed Quote feed
    event FeedsUpdated(Fungible indexed asset, AggregatorV3Interface baseFeed, AggregatorV3Interface quoteFeed);

    /// @notice Event emitted when the old feeds are deleted
    /// @param asset The address of the asset
    event FeedsDeleted(Fungible indexed asset);

    /// @notice Event emitted when the pool ID whitelist is updated
    /// @param id The pool ID
    event PoolIdWhitelistUpdated(PoolId indexed id, bool enabled);

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
    /// @dev The implementation automatically multiplies the base fee calculation result by the debtToken/token price.
    function updateFungibleFeedsConfig(Fungible asset, AggregatorV3Interface baseFeed, AggregatorV3Interface quoteFeed)
        external;

    /// @notice Delete the oracle configuration
    /// @param asset The address of the asset
    function deleteFungibleFeedsConfig(Fungible asset) external;

    /// @notice Add NFTs with specific pool IDs to the whitelist
    /// @param id Pool ID
    function updateNonFungiblePoolIdWhitelist(PoolId id) external;

    /// @notice Remove NFTs with specific pool IDs from the whitelist
    /// @param id Pool ID
    function deleteNonFungiblePoolIdWhitelist(PoolId id) external;
}
