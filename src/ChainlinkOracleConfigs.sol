// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {PoolId} from "@uniswap-v4-core/types/PoolId.sol";
import {AggregatorV3Interface} from "./interfaces/external/AggregatorV3Interface.sol";
import {IChainlinkOracleConfigs} from "./interfaces/IChainlinkOracleConfigs.sol";
import {ChainlinkDataFeedLib} from "./libraries/ChainlinkDataFeedLib.sol";
import {UniswapV4Module} from "./modules/uniswap/v4/UniswapV4Module.sol";
import {ModuleConfigs} from "./modules/ModuleConfigs.sol";
import {FeedsConfig} from "./types/FeedsConfig.sol";

/// @title ChainlinkOracleConfig
/// @notice Abstract contract for Chainlink oracle configurations
abstract contract ChainlinkOracleConfigs is IChainlinkOracleConfigs {
    using ChainlinkDataFeedLib for AggregatorV3Interface;

    UniswapV4Module internal uniswapV4Module;

    uint256 internal immutable debtFungibleDecimals;
    address internal governor;
    mapping(Fungible => FeedsConfig) internal feedConfigs;

    modifier onlyGovernor() {
        require(msg.sender == governor, NotGovernor());
        _;
    }

    constructor(uint256 _debtFungibleDecimals, address _governor) {
        debtFungibleDecimals = _debtFungibleDecimals;
        governor = _governor;

        uniswapV4Module.init(ModuleConfigs.uniswapV4PoolManager, ModuleConfigs.uniswapV4PositionManager);
    }

    /// @notice Update the new governor
    /// @param newGovernor The address of the new governor
    function updateGovernor(address newGovernor) external onlyGovernor {
        governor = newGovernor;

        emit UpdateGovernor(newGovernor);
    }

    function updateFungibleFeedsConfig(
        Fungible fungible,
        uint24 mrrPips,
        AggregatorV3Interface baseFeed,
        AggregatorV3Interface quoteFeed
    ) external onlyGovernor {
        uint8 fungibleDecimals = fungible.decimals();

        // emaPrice scaled by 1e18, and emaPrice = debt token amount(uniswap v4) / base token amount(uniswap v4)
        // output token = scaleFactor * (asset amount * baseFeed * emaPrice) / quoteFeed
        uint256 scaleFactor =
            10 ** (18 + quoteFeed.getDecimals() + debtFungibleDecimals - baseFeed.getDecimals() - fungibleDecimals);

        feedConfigs[fungible] =
            FeedsConfig({mrrPips: mrrPips, scaleFactor: scaleFactor, baseFeed: baseFeed, quoteFeed: quoteFeed});

        emit FeedsUpdate(fungible, mrrPips, baseFeed, quoteFeed);
    }

    function deleteFungibleFeedsConfig(Fungible fungible) external onlyGovernor {
        require(feedConfigs[fungible].scaleFactor != 0, NotExistFungibleFeedConfig());
        delete feedConfigs[fungible];

        emit FeedsDelete(fungible);
    }

    function initUniswapV4Module(address poolManager, address positionManager) external onlyGovernor {
        uniswapV4Module.init(poolManager, positionManager);
    }

    /// @notice Set the Uniswap V4 pool whitelist
    /// @param poolId The Uniswap V4 pool id
    /// @param enabled Whether the pool is whitelisted
    function setPoolWhitelist(PoolId poolId, bool enabled) external onlyGovernor {
        uniswapV4Module.setPoolWhitelist(poolId, enabled);
        emit UniswapV4WhitelistUpdated(poolId, enabled);
    }
}
