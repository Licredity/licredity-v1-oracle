// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {FixedPoint128} from "@uniswap-v4-core/libraries/FixedPoint128.sol";
import {FullMath} from "@uniswap-v4-core/libraries/FullMath.sol";
import {Position} from "@uniswap-v4-core/libraries/Position.sol";
import {SqrtPriceMath} from "@uniswap-v4-core/libraries/SqrtPriceMath.sol";
import {StateLibrary} from "@uniswap-v4-core/libraries/StateLibrary.sol";
import {TickMath} from "@uniswap-v4-core/libraries/TickMath.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";
import {PoolId} from "@uniswap-v4-core/types/PoolId.sol";
import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {IPositionManager} from "./interfaces/IPositionManager.sol";
import {PositionInfo} from "./types/PositionInfo.sol";

struct UniswapV4Module {
    IPoolManager poolManager;
    IPositionManager positionManager;
    mapping(PoolId => bool) positionWhitelist;
}

using UniswapV4ModuleLibrary for UniswapV4Module global;

library UniswapV4ModuleLibrary {
    using StateLibrary for IPoolManager;

    error AlreadyInitialized();

    /// @notice Initialize the module
    /// @param module The Uniswap V4 position module
    /// @param poolManager The Uniswap V4 pool manager
    /// @param positionManager The Uniswap V4 position manager
    function init(UniswapV4Module storage module, address poolManager, address positionManager) internal {
        require(address(module.poolManager) == address(0), AlreadyInitialized());

        module.poolManager = IPoolManager(poolManager);
        module.positionManager = IPositionManager(positionManager);
    }

    /// @notice Update the Uniswap V4 pool whitelist
    /// @param module The Uniswap V4 position module
    /// @param poolId The Uniswap V4 pool id
    /// @param whitelisted Whether the pool is whitelisted. If true, the pool is whitelisted
    function setPoolWhitelist(UniswapV4Module storage module, PoolId poolId, bool whitelisted) internal {
        module.positionWhitelist[poolId] = whitelisted;
    }

    /// @notice Get the value of a non-fungible
    /// @param module The Uniswap V4 position module
    /// @param positionId The LP position non-fungible to get the value of
    function getPositionValue(UniswapV4Module storage module, uint256 positionId)
        internal
        view
        returns (Fungible fungible0, uint256 amount0, Fungible fungible1, uint256 amount1)
    {
        IPoolManager poolManager = module.poolManager;
        IPositionManager positionManager = module.positionManager;

        // Check if the pool is whitelisted
        (PoolKey memory poolKey, PositionInfo positionInfo) = positionManager.getPoolAndPositionInfo(positionId);
        PoolId poolId = poolKey.toId();

        if (!module.positionWhitelist[poolId]) {
            return (
                Fungible.wrap(Currency.unwrap(poolKey.currency0)),
                0,
                Fungible.wrap(Currency.unwrap(poolKey.currency1)),
                0
            );
        }

        fungible0 = Fungible.wrap(Currency.unwrap(poolKey.currency0));
        fungible1 = Fungible.wrap(Currency.unwrap(poolKey.currency1));

        int24 tickLower = positionInfo.tickLower();
        int24 tickUpper = positionInfo.tickUpper();
        bytes32 positionKey =
            Position.calculatePositionKey(address(module.positionManager), tickLower, tickUpper, bytes32(positionId));

        // Fee
        (uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128) =
            poolManager.getPositionInfo(poolId, positionKey);

        (uint160 sqrtPriceX96, int24 tick,,) = poolManager.getSlot0(poolId);

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            poolManager.getFeeGrowthInside(poolId, tickLower, tickUpper);

        unchecked {
            amount0 += FullMath.mulDiv(feeGrowthInside0X128 - feeGrowthInside0LastX128, liquidity, FixedPoint128.Q128);
            amount1 += FullMath.mulDiv(feeGrowthInside1X128 - feeGrowthInside1LastX128, liquidity, FixedPoint128.Q128);
        }

        // Token in LP position
        if (tick < tickLower) {
            amount0 += SqrtPriceMath.getAmount0Delta(
                TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
            );
        } else if (tick < tickUpper) {
            amount0 +=
                SqrtPriceMath.getAmount0Delta(sqrtPriceX96, TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false);
            amount1 +=
                SqrtPriceMath.getAmount1Delta(TickMath.getSqrtPriceAtTick(tickLower), sqrtPriceX96, liquidity, false);
        } else {
            amount1 += SqrtPriceMath.getAmount1Delta(
                TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
            );
        }
    }
}
