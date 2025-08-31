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

    uint24 private constant FEE = 100;
    int24 private constant TICK_SPACING = 1;
    uint256 private constant POOL_MANAGER_OFFSET = 5;
    uint256 private constant CURRENCY0_OFFSET = 13;

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

        bytes32 currency0 = ILicredity(licredity).extsload(bytes32(CURRENCY0_OFFSET));

        PoolId _poolId;
        assembly ("memory-safe") {
            let memptr := mload(0x40)
            mstore(memptr, currency0) // currency0
            mstore(add(memptr, 0x20), licredity) // currency1
            mstore(add(memptr, 0x40), FEE) // fee
            mstore(add(memptr, 0x60), TICK_SPACING) // tickSpacing
            mstore(add(memptr, 0x80), licredity) // hooks

            _poolId := keccak256(memptr, 0xa0)
            mstore(0x40, add(memptr, 0xa0)) // update free memory pointer
        }

        poolId = _poolId;
        debtFungible = Fungible.wrap(licredity);

        lastUpdateTimeStamp = block.timestamp;
        currentTimeStamp = block.timestamp;

        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);
        require(sqrtPriceX96 != 0);

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
    function quoteNonFungibles(NonFungible[] calldata nonFungibles)
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
        // price from square root price
        uint256 priceX96 = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> 96;

        // short circuit if neither price nor timestamp has changed
        if (priceX96 == lastPriceX96 && currentTimeStamp == block.timestamp) {
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
            uint256 baseFeedPrice = fungibleConfigs[fungible].baseFeed.getPrice(maxStaleness);
            uint256 quoteFeedPrice = fungibleConfigs[fungible].quoteFeed.getPrice(maxStaleness);

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
        Fungible fungible0;
        uint256 amount0;
        Fungible fungible1;
        uint256 amount1;

        // dispatch to other modules using token address
        if (nonFungible.tokenAddress() == address(uniswapV4Module.positionManager)) {
            (fungible0, amount0, fungible1, amount1) = uniswapV4Module.getPositionValue(nonFungible.tokenId());
        } else if (nonFungible.tokenAddress() == address(uniswapV3Module.positionManager)) {
            (fungible0, amount0, fungible1, amount1) = uniswapV3Module.getPositionValue(nonFungible.tokenId());
        }

        // update value and marginRequirement for fungible0
        if (amount0 > 0) {
            (uint256 value0, uint256 marginRequirement0) = _quoteFungible(fungible0, amount0);
            value += value0;
            marginRequirement += marginRequirement0;
        }

        // update value and marginRequirement for fungible1
        if (amount1 > 0) {
            (uint256 value1, uint256 marginRequirement1) = _quoteFungible(fungible1, amount1);
            value += value1;
            marginRequirement += marginRequirement1;
        }
    }
}
