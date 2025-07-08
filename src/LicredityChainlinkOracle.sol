// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.30;

import {ILicredityChainlinkOracle} from "./interfaces/ILicredityChainlinkOracle.sol";
import {AggregatorV3Interface} from "./interfaces/external/AggregatorV3Interface.sol";
import {OracleConfig} from "./OracleConfig.sol";
import {Fungible} from "./types/Fungible.sol";
import {NonFungible} from "./types/NonFungible.sol";
import {PositionValue} from "./types/PositionValue.sol";
import {ChainlinkDataFeedLib} from "./libraries/ChainlinkDataFeedLib.sol";
import {FixedPointMath} from "./libraries/FixedPointMath.sol";
import {FeedsConfig} from "./libraries/FeedsConfig.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

contract LicredityChainlinkOracle is ILicredityChainlinkOracle, OracleConfig {
    using FixedPointMath for int256;
    using FixedPointMath for uint256;

    using ChainlinkDataFeedLib for AggregatorV3Interface;
    using StateLibrary for IPoolManager;

    PoolId public poolId;
    IPoolManager immutable poolManager;

    uint256 public lastPriceX96;
    uint256 internal currentPriceX96;
    uint256 public emaPrice;
    uint256 public lastUpdateTimeStamp;
    uint256 internal currentTimeStamp;

    constructor(address licredity_, address owner_, PoolId poolId_, IPoolManager poolManager_)
        OracleConfig(licredity_, owner_)
    {
        poolId = poolId_;
        poolManager = poolManager_;

        lastUpdateTimeStamp = block.timestamp;
        currentTimeStamp = block.timestamp;

        currentPriceX96 = 1 << 96;
        lastPriceX96 = 1 << 96;
        emaPrice = 1e18;
    }

    function quotePrice() external view returns (uint256 price) {
        price = emaPrice;
    }

    function quoteFungible(Fungible fungible, uint256 amount)
        internal
        view
        returns (uint256 debtTokenAmount, uint256 marginRequirement)
    {
        if (fungible == Fungible.wrap(licredity)) {
            debtTokenAmount = amount;
            marginRequirement = 0;
        } else {
            uint24 mrrPips = feeds[fungible].mrrPips;
            uint256 scaleFactor = feeds[fungible].scaleFactor;

            if (scaleFactor == 0) {
                return (0, 0);
            }

            FeedsConfig memory config = feeds[fungible];

            // output debt token amount = scaleFactor * (input token amount * baseFeed * emaPrice) / quoteFeed
            debtTokenAmount = (emaPrice * config.scaleFactor).fullMulDiv(
                amount * config.baseFeed.getPrice(), config.quoteFeed.getPrice() * 1e36
            );

            marginRequirement = debtTokenAmount.mulPipsUp(mrrPips);
        }
    }

    function quoteFungibles(Fungible[] calldata fungibles, uint256[] calldata amounts)
        external
        returns (uint256 value, uint256 marginRequirement)
    {
        update();
        uint256 count = fungibles.length;

        for (uint256 i = 0; i < count; i++) {
            Fungible fungible = fungibles[i];
            uint256 amount = amounts[i];

            (uint256 _value, uint256 _marginRequirement) = quoteFungible(fungible, amount);

            value += _value;
            marginRequirement += _marginRequirement;
        }
    }

    function quoteNonFungible(NonFungible nonFungible)
        internal
        view
        returns (uint256 debtTokenAmount, uint256 marginRequirement)
    {
        address token = nonFungible.tokenAddress();
        PositionValue memory position;

        // dispatch to other modules using token address
        if (address(token) == address(uniswapV4PositionState.positionManager)) {
            position = uniswapV4PositionState.getPositionValue(nonFungible);
        } else {
            return (0, 0);
        }

        if (position.token0Amount == 0 && position.token1Amount == 0) {
            return (0, 0);
        }
        
        (uint256 debtToken0Amount, uint256 margin0Requirement) = quoteFungible(position.token0, position.token0Amount);
        (uint256 debtToken1Amount, uint256 margin1Requirement) = quoteFungible(position.token1, position.token1Amount);

        debtTokenAmount = debtToken0Amount + debtToken1Amount;
        marginRequirement = margin0Requirement + margin1Requirement;
    }

    function quoteNonFungibles(NonFungible[] memory nonFungibles)
        external
        returns (uint256 value, uint256 marginRequirement)
    {
        update();
        uint256 count = nonFungibles.length;

        for (uint256 i = 0; i < count; i++) {
            (uint256 _value, uint256 _marginRequirement) = quoteNonFungible(nonFungibles[i]);

            value += _value;
            marginRequirement += _marginRequirement;
        }
    }

    function update() public {
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);

        if (sqrtPriceX96 == lastPriceX96 && currentTimeStamp == block.timestamp) {
            return;
        }

        if (block.timestamp != currentTimeStamp) {
            lastUpdateTimeStamp = currentTimeStamp;
            currentTimeStamp = block.timestamp;
            lastPriceX96 = currentPriceX96;
        }

        // alpha = e ^ -(block.timestamp - lastUpdateTimeStamp)
        int256 power = ((int256(lastUpdateTimeStamp) - int256(block.timestamp)) << 96) / 600;
        uint256 alphaX96 = uint256(power.expWadX96());

        uint256 priceX96 = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> 96;

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
}
