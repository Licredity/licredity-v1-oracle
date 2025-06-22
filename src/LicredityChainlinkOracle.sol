// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.30;

import {ILicredityChainlinkOracle} from "./interfaces/ILicredityChainlinkOracle.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {Fungible} from "./types/Fungible.sol";
import {NonFungible} from "./types/NonFungible.sol";
import {PositionInfo} from "./types/PositionInfo.sol";
import {ChainlinkDataFeedLib} from "./libraries/ChainlinkDataFeedLib.sol";
import {FeedsConfig} from "./libraries/FeedsConfig.sol";
import {FixedPointMath} from "./libraries/FixedPointMath.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {Position} from "v4-core/libraries/Position.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {FixedPoint128} from "v4-core/libraries/FixedPoint128.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IPositionManager} from "./interfaces/IPositionManager.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

contract LicredityChainlinkOracle is ILicredityChainlinkOracle {
    using FixedPointMath for int256;
    using FixedPointMath for uint256;
    using ChainlinkDataFeedLib for AggregatorV3Interface;
    using StateLibrary for IPoolManager;

    error NotLicredity();
    error NotSupportedNonFungible();
    error NotUniswapV4Position();
    error NotOwner();

    PoolId public poolId;
    IPoolManager immutable poolManager;
    IPositionManager immutable positionManager;
    address public licredity;
    address public owner;

    uint256 public lastPriceX96;
    uint256 public currentPriceX96;
    uint256 public emaPrice;
    uint256 public lastUpdateTimeStamp;
    uint256 public currentTimeStamp;

    mapping(Fungible => FeedsConfig) public feeds;
    mapping(PoolId => bool) public nonFungiblePoolIdWhitelist;

    constructor(
        address licredity_,
        address owner_,
        PoolId poolId_,
        IPoolManager poolManager_,
        IPositionManager positionManager_
    ) {
        licredity = licredity_;
        owner = owner_;
        poolId = poolId_;
        poolManager = poolManager_;
        positionManager = positionManager_;

        lastUpdateTimeStamp = block.timestamp;
        currentTimeStamp = block.timestamp;

        currentPriceX96 = 1 << 96;
        lastPriceX96 = 1 << 96;
        emaPrice = 1e18;
    }

    modifier onlyLicredity() {
        require(msg.sender == licredity, NotLicredity());
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, NotOwner());
        _;
    }

    function updateOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function quotePrice() public view returns (uint256) {
        return emaPrice;
    }

    /// @notice Returns the number of debt tokens that can be exchanged for the assets.
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

            // If asset is token, need to set both baseFeed and quoteFeed of token to zero addresses
            // scaleFactor * (amount * baseFeed) / (emaPrice * quoteFeed)
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

    struct PositionState {
        uint256 token0Amount;
        uint256 token1Amount;
    }

    function quoteNonFungible(NonFungible nonFungible)
        internal
        view
        returns (uint256 debtTokenAmount, uint256 marginRequirement)
    {
        address token = nonFungible.token();
        uint256 id = nonFungible.id();

        require(token == address(positionManager), NotSupportedNonFungible());

        (PoolKey memory poolKey, PositionInfo positionInfo) = positionManager.getPoolAndPositionInfo(id);

        PoolId _poolId = poolKey.toId();

        require(nonFungiblePoolIdWhitelist[_poolId], NotSupportedNonFungible());

        PositionState memory state;

        {
            (uint160 sqrtPriceX96, int24 tick,,) = poolManager.getSlot0(_poolId);

            int24 tickLower = positionInfo.tickLower();
            int24 tickUpper = positionInfo.tickUpper();

            bytes32 positionId =
                Position.calculatePositionKey(address(positionManager), tickLower, tickUpper, bytes32(id));

            (uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128) =
                poolManager.getPositionInfo(poolId, positionId);

            // Fee
            (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
                poolManager.getFeeGrowthInside(poolId, tickLower, tickUpper);

            unchecked {
                state.token0Amount +=
                    FullMath.mulDiv(feeGrowthInside0X128 - feeGrowthInside0LastX128, liquidity, FixedPoint128.Q128);
                state.token1Amount +=
                    FullMath.mulDiv(feeGrowthInside1X128 - feeGrowthInside1LastX128, liquidity, FixedPoint128.Q128);
            }

            // Token in LP
            if (tick < tickLower) {
                state.token0Amount += SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
                );
            } else if (tick < tickUpper) {
                state.token0Amount += SqrtPriceMath.getAmount0Delta(
                    sqrtPriceX96, TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
                );
                state.token1Amount += SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtPriceAtTick(tickLower), sqrtPriceX96, liquidity, false
                );
            } else {
                state.token1Amount += SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
                );
            }
        }

        (uint256 debtToken0Amount, uint256 margin0Requirement) =
            quoteFungible(Fungible.wrap(Currency.unwrap(poolKey.currency0)), state.token0Amount);
        (uint256 debtToken1Amount, uint256 margin1Requirement) =
            quoteFungible(Fungible.wrap(Currency.unwrap(poolKey.currency1)), state.token1Amount);

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

    function updateFungibleFeedsConfig(
        Fungible asset,
        uint24 mrrPips,
        AggregatorV3Interface baseFeed,
        AggregatorV3Interface quoteFeed
    ) external onlyOwner {
        uint8 assetTokenDecimals = asset.decimals();
        uint8 debtTokenDecimals = Fungible.wrap(licredity).decimals();

        uint256 scaleFactor =
            10 ** (18 + quoteFeed.getDecimals() + debtTokenDecimals - baseFeed.getDecimals() - assetTokenDecimals);

        feeds[asset] =
            FeedsConfig({mrrPips: mrrPips, scaleFactor: scaleFactor, baseFeed: baseFeed, quoteFeed: quoteFeed});

        emit FeedsUpdated(asset, mrrPips, baseFeed, quoteFeed);
    }

    function deleteFungibleFeedsConfig(Fungible asset) external onlyOwner {
        delete feeds[asset];

        emit FeedsDeleted(asset);
    }

    function updateNonFungiblePoolIdWhitelist(PoolId id) external onlyOwner {
        nonFungiblePoolIdWhitelist[id] = true;

        emit PoolIdWhitelistUpdated(id, true);
    }

    function deleteNonFungiblePoolIdWhitelist(PoolId id) external onlyOwner {
        delete nonFungiblePoolIdWhitelist[id];

        emit PoolIdWhitelistUpdated(id, false);
    }
}
