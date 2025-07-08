// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.30;

import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {StateLibrary} from "@uniswap-v4-core/libraries/StateLibrary.sol";
import {PoolId} from "@uniswap-v4-core/types/PoolId.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {IOracle} from "@licredity-v1-core/interfaces/IOracle.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {NonFungible} from "@licredity-v1-core/types/NonFungible.sol";
import {AggregatorV3Interface} from "./interfaces/external/AggregatorV3Interface.sol";
import {IChainlinkOracle} from "./interfaces/IChainlinkOracle.sol";
import {ChainlinkDataFeedLib} from "./libraries/ChainlinkDataFeedLib.sol";
import {FixedPointMath} from "./libraries/FixedPointMath.sol";
import {FeedsConfig} from "./types/FeedsConfig.sol";
import {ChainlinkOracleConfigs} from "./ChainlinkOracleConfigs.sol";

contract ChainlinkOracle is IChainlinkOracle, ChainlinkOracleConfigs {
    using FixedPointMath for int256;
    using FixedPointMath for uint256;
    using StateLibrary for IPoolManager;
    using ChainlinkDataFeedLib for AggregatorV3Interface;

    uint256 private constant POOL_MANAGER_OFFSET = 5;
    uint256 private constant POOL_ID_OFFSET = 14;

    IPoolManager internal immutable poolManager;
    PoolId internal immutable poolId;
    Fungible internal immutable debtFungible;

    uint256 public emaPrice;
    uint256 public currentPriceX96;
    uint256 public currentTimeStamp;
    uint256 public lastPriceX96;
    uint256 public lastUpdateTimeStamp;

    constructor(address _licredity, address _governor)
        ChainlinkOracleConfigs(Fungible.wrap(_licredity).decimals(), _governor)
    {
        poolManager =
            IPoolManager(address(uint160(uint256(ILicredity(_licredity).extsload(bytes32(POOL_MANAGER_OFFSET))))));
        poolId = PoolId.wrap(ILicredity(_licredity).extsload(bytes32(POOL_ID_OFFSET)));
        debtFungible = Fungible.wrap(_licredity);

        lastUpdateTimeStamp = block.timestamp;
        currentTimeStamp = block.timestamp;

        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);
        currentPriceX96 = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> 96;
        lastPriceX96 = currentPriceX96;
        emaPrice = (currentPriceX96 * 1e18) >> 96;
    }

    /// @inheritdoc IOracle
    function quotePrice() external view returns (uint256 price) {
        price = emaPrice;
    }

    /// @inheritdoc IOracle
    function quoteFungibles(Fungible[] calldata fungibles, uint256[] calldata amounts)
        external
        returns (uint256 value, uint256 marginRequirement)
    {
        update();

        for (uint256 i = 0; i < fungibles.length; i++) {
            Fungible fungible = fungibles[i];
            uint256 amount = amounts[i];

            (uint256 _value, uint256 _marginRequirement) = _quoteFungible(fungible, amount);

            value += _value;
            marginRequirement += _marginRequirement;
        }
    }

    /// @inheritdoc IOracle
    function quoteNonFungibles(NonFungible[] memory nonFungibles)
        external
        returns (uint256 value, uint256 marginRequirement)
    {
        update();

        for (uint256 i = 0; i < nonFungibles.length; i++) {
            (uint256 _value, uint256 _marginRequirement) = _quoteNonFungible(nonFungibles[i]);

            value += _value;
            marginRequirement += _marginRequirement;
        }
    }

    /// @inheritdoc IOracle
    function update() public {
        // get current price
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);

        // short circuit if neither price nor timestamp has changed
        if (sqrtPriceX96 == lastPriceX96 && currentTimeStamp == block.timestamp) {
            return;
        }

        // if timestamp has changed, update cache
        if (block.timestamp != currentTimeStamp) {
            lastUpdateTimeStamp = currentTimeStamp;
            currentTimeStamp = block.timestamp;
            lastPriceX96 = currentPriceX96;
        }

        // alpha = e ^ -(block.timestamp - lastUpdateTimeStamp)
        int256 power = ((int256(lastUpdateTimeStamp) - int256(block.timestamp)) << 96) / 600;
        uint256 alphaX96 = uint256(power.expWadX96());

        // price from square root price
        uint256 priceX96 = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> 96;

        // cap cross block price movement to 1.5625%
        // If priceX96 > lastPriceX96 * (1 + 0.015625), priceX96 = lastPriceX96 * (1 + 0.015625)
        // If priceX96 < lastPriceX96 * (1 - 0.015625), priceX96 = lastPriceX96 * (1 - 0.015625)
        // 0.015625 = 1 / (2 ** 6)
        uint256 priceX96Range = lastPriceX96 >> 6;
        priceX96 = priceX96.clamp(lastPriceX96 - priceX96Range, lastPriceX96 + priceX96Range);

        // emaPriceX192 = alpha * priceX96 + (1 - alpha) * lastPriceX96
        uint256 emaPriceX96 = (alphaX96 * priceX96 + (0x1000000000000000000000000 - alphaX96) * lastPriceX96) >> 96;

        // Update lastPriceX96 and emaPrice
        currentPriceX96 = emaPriceX96;
        emaPrice = (emaPriceX96 * 1e18) >> 96;
    }

    function _quoteFungible(Fungible fungible, uint256 amount)
        internal
        view
        returns (uint256 value, uint256 marginRequirement)
    {
        if (fungible == debtFungible) {
            // debt fungible
            value = amount;
            marginRequirement = 0;
        } else {
            uint256 scaleFactor = feedConfigs[fungible].scaleFactor;

            // unregistered fungible
            if (scaleFactor == 0) {
                return (0, 0);
            }

            uint24 mrrPips = feedConfigs[fungible].mrrPips;
            uint256 baseFeedPrice = feedConfigs[fungible].baseFeed.getPrice();
            uint256 quoteFeedPrice = feedConfigs[fungible].quoteFeed.getPrice();

            // output value = scaleFactor * (input token amount * baseFeed * emaPrice) / quoteFeed
            value = (emaPrice * scaleFactor).fullMulDiv(amount * baseFeedPrice, quoteFeedPrice * 1e36);

            marginRequirement = value.mulPipsUp(mrrPips);
        }
    }

    function _quoteNonFungible(NonFungible nonFungible)
        internal
        view
        returns (uint256 debtTokenAmount, uint256 marginRequirement)
    {
        address token = nonFungible.tokenAddress();

        // dispatch to other modules using token address
        if (address(token) == address(uniswapV4Module.positionManager)) {
            (Fungible fungible0, uint256 amount0, Fungible fungible1, uint256 amount1) =
                uniswapV4Module.getPositionValue(nonFungible);

            if (amount0 > 0) {
                (uint256 debtToken0Amount, uint256 margin0Requirement) = _quoteFungible(fungible0, amount0);
                debtTokenAmount += debtToken0Amount;
            }

            if (amount1 > 0) {
                (uint256 debtToken1Amount, uint256 margin1Requirement) = _quoteFungible(fungible1, amount1);
                debtTokenAmount += debtToken1Amount;
            }
        } else {
            return (0, 0);
        }
    }
}
