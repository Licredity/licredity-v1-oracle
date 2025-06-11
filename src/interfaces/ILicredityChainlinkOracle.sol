// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";
import {IOracle} from "./IOracle.sol";
import {Fungible} from "../types/Fungible.sol";
import {NonFungible} from "../types/NonFungible.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

interface ILicredityChainlinkOracle is IOracle {
    /// @notice Event emitted when the new feeds are set
    /// @param asset The address of the asset
    /// @param baseFeed Base feed
    /// @param quoteFeed Quote feed
    event FeedsUpdated(Fungible indexed asset, uint16 mrrBps, AggregatorV3Interface baseFeed, AggregatorV3Interface quoteFeed);

    /// @notice Event emitted when the old feeds are deleted
    /// @param asset The address of the asset
    event FeedsDeleted(Fungible indexed asset);

    /// @notice Event emitted when the pool ID whitelist is updated
    /// @param id The pool ID
    event PoolIdWhitelistUpdated(PoolId indexed id, bool enabled);

    /// @notice Provides multiple oracle configurations for asset to debt token price calculations
    /// @param asset The address of the asset
    /// @param baseFeed Base feed. Pass address zero if the price = 1
    /// @param quoteFeed Quote feed. Pass address zero if the price = 1
    /// @dev The implementation automatically multiplies the base fee calculation result by the debtToken/token price.
    function updateFungibleFeedsConfig(Fungible asset, uint16 mrrBps, AggregatorV3Interface baseFeed, AggregatorV3Interface quoteFeed)
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
