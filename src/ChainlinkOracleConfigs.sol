// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {PoolId} from "@uniswap-v4-core/types/PoolId.sol";
import {AggregatorV3Interface} from "./interfaces/external/AggregatorV3Interface.sol";
import {IChainlinkOracleConfigs} from "./interfaces/IChainlinkOracleConfigs.sol";
import {ChainlinkFeedLibrary} from "./libraries/ChainlinkFeedLibrary.sol";
import {FixedPointMath} from "./libraries/FixedPointMath.sol";
import {UniswapV4Module} from "./modules/uniswap/v4/UniswapV4Module.sol";
import {UniswapV3Module} from "./modules/uniswap/v3/UniswapV3Module.sol";

/// @title ChainlinkOracleConfigs
/// @notice Abstract contract for Chainlink oracle configurations
abstract contract ChainlinkOracleConfigs is IChainlinkOracleConfigs {
    /// @title FungibleConfig
    /// @notice Configuration for a fungible used in the oracle
    struct FungibleConfig {
        /// @notice The fungible's margin requirement ratio in pips
        uint24 mrrPips;
        uint256 scaleFactor;
        AggregatorV3Interface baseFeed;
        AggregatorV3Interface quoteFeed;
    }

    using ChainlinkFeedLibrary for AggregatorV3Interface;

    error NotGovernor();
    error InvalidMrrPips();

    UniswapV4Module internal uniswapV4Module;
    UniswapV3Module internal uniswapV3Module;

    address internal governor;
    mapping(Fungible => FungibleConfig) internal fungibleConfigs;

    modifier onlyGovernor() {
        require(msg.sender == governor, NotGovernor());
        _;
    }

    constructor(address _governor) {
        governor = _governor;
    }

    /// @inheritdoc IChainlinkOracleConfigs
    function updateGovernor(address newGovernor) external onlyGovernor {
        governor = newGovernor;

        emit UpdateGovernor(newGovernor);
    }

    /// @inheritdoc IChainlinkOracleConfigs
    function setFungibleConfig(
        Fungible fungible,
        uint24 mrrPips,
        AggregatorV3Interface baseFeed,
        AggregatorV3Interface quoteFeed
    ) external onlyGovernor {
        require(mrrPips <= FixedPointMath.UNIT_PIPS, InvalidMrrPips());

        // scaled factor between base and quote fungibles, amplified by 1e18 to prevent negative number
        uint256 scaleFactor = 10
            ** (18 + quoteFeed.getDecimals() + _getQuoteFungibleDecimals() - baseFeed.getDecimals() - fungible.decimals());

        fungibleConfigs[fungible] =
            FungibleConfig({mrrPips: mrrPips, scaleFactor: scaleFactor, baseFeed: baseFeed, quoteFeed: quoteFeed});

        emit SetFungibleConfig(fungible, mrrPips, scaleFactor, baseFeed, quoteFeed);
    }

    /// @inheritdoc IChainlinkOracleConfigs
    function deleteFungibleConfig(Fungible fungible) external onlyGovernor {
        delete fungibleConfigs[fungible];

        emit DeleteFungibleConfig(fungible);
    }

    /// @inheritdoc IChainlinkOracleConfigs
    function initializeUniswapV4Module(address poolManager, address positionManager) external onlyGovernor {
        uniswapV4Module.initialize(poolManager, positionManager);

        emit InitializeUniswapV4Module(poolManager, positionManager);
    }

    /// @inheritdoc IChainlinkOracleConfigs
    function setUniswapV4Pool(PoolId poolId, bool isWhitelisted) external onlyGovernor {
        uniswapV4Module.setPool(poolId, isWhitelisted);

        emit SetUniswapV4Pool(poolId, isWhitelisted);
    }

    function initializeUniswapV3Module(address uniswapV3Factory, address positionManager) external onlyGovernor {
        uniswapV3Module.initialize(uniswapV3Factory, positionManager);

        emit InitializeUniswapV3Module(uniswapV3Factory, positionManager);
    }

    function setUniswapV3Pool(address pool, bool isWhitelisted) external onlyGovernor {
        uniswapV3Module.setWhitelistPool(pool, isWhitelisted);

        emit SetUniswapV3Pool(pool, isWhitelisted);
    }

    function _getQuoteFungibleDecimals() internal view virtual returns (uint256 decimals);
}
