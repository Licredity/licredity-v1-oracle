// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Fungible} from "./types/Fungible.sol";
import {FeedsConfig} from "./libraries/FeedsConfig.sol";
import {ChainlinkDataFeedLib} from "./libraries/ChainlinkDataFeedLib.sol";
import {UniswapV4PositionState} from "./modules/uniswap/v4/V4Position.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {IPositionConfig} from "./interfaces/IPositionConfig.sol";
import {IPoolManager as IUniswapV4PoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUniswapV4PositionManager} from "./interfaces/external/IUniswapV4PositionManager.sol";
import {AggregatorV3Interface} from "./interfaces/external/AggregatorV3Interface.sol";

contract OracleConfig is IPositionConfig {
    using ChainlinkDataFeedLib for AggregatorV3Interface;

    error NotGovernor();
    error NotExistFungibleFeedConfig();
    error NotExistNonFungiblePoolIdWhitelist();

    address internal licredity;
    address internal governor;
    UniswapV4PositionState internal uniswapV4PositionState;
    mapping(Fungible => FeedsConfig) internal feeds;

    constructor(address licredity_, address governor_) {
        licredity = licredity_;
        governor = governor_;
    }

    modifier onlyGovernor() {
        require(msg.sender == governor, NotGovernor());
        _;
    }

    function updateGovernor(address _newGovernor) external onlyGovernor {
        governor = _newGovernor;
        emit UpdateGovernor(governor);
    }

    function updateFungibleFeedsConfig(
        Fungible asset,
        uint24 mrrPips,
        AggregatorV3Interface baseFeed,
        AggregatorV3Interface quoteFeed
    ) external onlyGovernor {
        uint8 assetTokenDecimals = asset.decimals();
        uint8 debtTokenDecimals = Fungible.wrap(licredity).decimals();

        uint256 scaleFactor =
            10 ** (18 + quoteFeed.getDecimals() + debtTokenDecimals - baseFeed.getDecimals() - assetTokenDecimals);

        feeds[asset] =
            FeedsConfig({mrrPips: mrrPips, scaleFactor: scaleFactor, baseFeed: baseFeed, quoteFeed: quoteFeed});

        emit FeedsUpdate(asset, mrrPips, baseFeed, quoteFeed);
    }

    function deleteFungibleFeedsConfig(Fungible asset) external onlyGovernor {
        require(feeds[asset].scaleFactor != 0, NotExistFungibleFeedConfig());
        delete feeds[asset];

        emit FeedsDelete(asset);
    }

    function initUniswapV4PositionModule(IUniswapV4PoolManager poolManager, IUniswapV4PositionManager positionManager)
        external
        onlyGovernor
    {
        uniswapV4PositionState.init(poolManager, positionManager);
    }

    function setUniswapV4Whitelist(PoolId poolId, bool enabled) external onlyGovernor {
        uniswapV4PositionState.updateV4PoolWhitelist(poolId, enabled);
        emit UniswapV4WhitelistUpdated(poolId, enabled);
    }
}
