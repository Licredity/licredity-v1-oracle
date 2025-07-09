// SPDX-License-Identifier: MIT
pragma solidity =0.8.30;

import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {IOracle} from "@licredity-v1-core/interfaces/IOracle.sol";
import {FullMath} from "@licredity-v1-core/libraries/FullMath.sol";
import {PipsMath} from "@licredity-v1-core/libraries/PipsMath.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {NonFungible} from "@licredity-v1-core/types/NonFungible.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {StateLibrary} from "@uniswap-v4-core/libraries/StateLibrary.sol";
import {PoolId} from "@uniswap-v4-core/types/PoolId.sol";
import {AggregatorV3Interface} from "./interfaces/external/AggregatorV3Interface.sol";
import {IChainlinkOracle} from "./interfaces/IChainlinkOracle.sol";
import {ChainlinkFeedLibrary} from "./libraries/ChainlinkFeedLibrary.sol";
import {FixedPointMath} from "./libraries/FixedPointMath.sol";
import {ChainlinkOracleConfigs} from "./ChainlinkOracleConfigs.sol";

contract ChainlinkOracle is IChainlinkOracle, ChainlinkOracleConfigs {
    using FixedPointMath for int256;
    using FixedPointMath for uint256;
    using FullMath for uint256;
    using PipsMath for uint256;
    using StateLibrary for IPoolManager;
    using ChainlinkFeedLibrary for AggregatorV3Interface;

    uint256 private constant POOL_MANAGER_OFFSET = 5;
    uint256 private constant POOL_ID_OFFSET = 14;

    uint256 public emaPrice;
    uint256 public currentPriceX96;
    uint256 public currentTimeStamp;
    uint256 public lastPriceX96;
    uint256 public lastUpdateTimeStamp;

    IPoolManager internal immutable poolManager;
    PoolId internal immutable poolId;
    Fungible internal immutable debtFungible;

    constructor(address licredity, address _governor) ChainlinkOracleConfigs(_governor) {
        poolManager =
            IPoolManager(address(uint160(uint256(ILicredity(licredity).extsload(bytes32(POOL_MANAGER_OFFSET))))));
        poolId = PoolId.wrap(ILicredity(licredity).extsload(bytes32(POOL_ID_OFFSET)));
        debtFungible = Fungible.wrap(licredity);

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
        // update price as time may have passed since last update
        update();

        for (uint256 i = 0; i < fungibles.length; i++) {
            (uint256 _value, uint256 _marginRequirement) = _quoteFungible(fungibles[i], amounts[i]);

            value += _value;
            marginRequirement += _marginRequirement;
        }
    }

    /// @inheritdoc IOracle
    function quoteNonFungibles(NonFungible[] memory nonFungibles)
        external
        returns (uint256 value, uint256 marginRequirement)
    {
        // update price as time may have passed since last update
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
            lastPriceX96 = currentPriceX96;
            lastUpdateTimeStamp = currentTimeStamp;
            currentTimeStamp = block.timestamp;
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

    function _getQuoteFungibleDecimals() internal view override returns (uint256) {
        return debtFungible.decimals();
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
            uint256 scaleFactor = fungibleConfigs[fungible].scaleFactor;

            // unregistered fungible
            if (scaleFactor == 0) {
                return (0, 0);
            }

            uint24 mrrPips = fungibleConfigs[fungible].mrrPips;
            uint256 baseFeedPrice = fungibleConfigs[fungible].baseFeed.getPrice();
            uint256 quoteFeedPrice = fungibleConfigs[fungible].quoteFeed.getPrice();

            // output value = scaleFactor * (input token amount * baseFeed * emaPrice) / quoteFeed
            // divide by 1e36 to account for 1) emaPrice has 1e18 decimals, and 2) scaleFactor is amplified by 1e18
            value = (emaPrice * scaleFactor).fullMulDiv(amount * baseFeedPrice, quoteFeedPrice * 1e36);
            marginRequirement = value.pipsMulUp(mrrPips);
        }
    }

    function _quoteNonFungible(NonFungible nonFungible)
        internal
        view
        returns (uint256 value, uint256 marginRequirement)
    {
        // dispatch to other modules using token address
        if (nonFungible.tokenAddress() == address(uniswapV4Module.positionManager)) {
            (Fungible fungible0, uint256 amount0, Fungible fungible1, uint256 amount1) =
                uniswapV4Module.getPositionValue(nonFungible.tokenId());

            if (amount0 > 0) {
                (uint256 debtToken0Amount, uint256 margin0Requirement) = _quoteFungible(fungible0, amount0);
                value += debtToken0Amount;
                marginRequirement += margin0Requirement;
            }

            if (amount1 > 0) {
                (uint256 debtToken1Amount, uint256 margin1Requirement) = _quoteFungible(fungible1, amount1);
                value += debtToken1Amount;
                marginRequirement += margin1Requirement;
            }
        }
    }
}
