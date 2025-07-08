// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PositionInfo} from "./PositionInfo.sol";
import {NonFungible} from "src/types/NonFungible.sol";
import {Fungible} from "src/types/Fungible.sol";
import {PositionValue} from "src/types/PositionValue.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {Position} from "v4-core/libraries/Position.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {FixedPoint128} from "v4-core/libraries/FixedPoint128.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUniswapV4PositionManager} from "src/interfaces/external/IUniswapV4PositionManager.sol";

struct UniswapV4PositionState {
    IPoolManager poolManager;
    IUniswapV4PositionManager positionManager;
    mapping(PoolId => bool) positionWhitelist;
}

using UniswapV4PositionLibrary for UniswapV4PositionState global;

library UniswapV4PositionLibrary {
    using StateLibrary for IPoolManager;

    error AlreadyInitialized();

    /// @notice Initialize the module
    /// @param state The Uniswap V4 position module state
    /// @param poolManager The Uniswap V4 pool manager
    /// @param positionManager The Uniswap V4 position manager
    function init(
        UniswapV4PositionState storage state,
        IPoolManager poolManager,
        IUniswapV4PositionManager positionManager
    ) internal {
        require(address(state.poolManager) == address(0), AlreadyInitialized());

        state.poolManager = poolManager;
        state.positionManager = positionManager;
    }

    /// @notice Update the Uniswap V4 pool whitelist
    /// @param state The Uniswap V4 position module state
    /// @param poolId The Uniswap V4 pool id
    /// @param enabled Whether the pool is whitelisted. If true, the pool is whitelisted
    function updateV4PoolWhitelist(UniswapV4PositionState storage state, PoolId poolId, bool enabled) internal {
        state.positionWhitelist[poolId] = enabled;
    }

    struct PositionComputations {
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint160 sqrtPriceX96;
        int24 tick;
    }

    /// @notice Get the value of a non-fungible
    /// @param state The Uniswap V4 position module state
    /// @param nonFungible The LP position non-fungible to get the value of
    /// @return position The value of the position
    function getPositionValue(UniswapV4PositionState storage state, NonFungible nonFungible)
        internal
        view
        returns (PositionValue memory position)
    {
        IUniswapV4PositionManager positionManager = state.positionManager;
        IPoolManager poolManager = state.poolManager;

        PositionComputations memory computation;

        // Check if the pool is whitelisted
        uint256 id = nonFungible.tokenId();
        (PoolKey memory poolKey, PositionInfo positionInfo) = positionManager.getPoolAndPositionInfo(id);
        PoolId poolId = poolKey.toId();

        if (!state.positionWhitelist[poolId]) {
            position.token0Amount = 0;
            position.token1Amount = 0;
            return position;
        }
        
        position.token0 = Fungible.wrap(Currency.unwrap(poolKey.currency0));
        position.token1 = Fungible.wrap(Currency.unwrap(poolKey.currency1));

        int24 tickLower = positionInfo.tickLower();
        int24 tickUpper = positionInfo.tickUpper();
        bytes32 positionId =
            Position.calculatePositionKey(address(state.positionManager), tickLower, tickUpper, bytes32(id));

        // Fee
        uint128 liquidity;
        (liquidity, computation.feeGrowthInside0LastX128, computation.feeGrowthInside1LastX128) =
            poolManager.getPositionInfo(poolId, positionId);

        (computation.sqrtPriceX96, computation.tick,,) = poolManager.getSlot0(poolId);

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            poolManager.getFeeGrowthInside(poolId, tickLower, tickUpper);

        unchecked {
            position.token0Amount += FullMath.mulDiv(
                feeGrowthInside0X128 - computation.feeGrowthInside0LastX128, liquidity, FixedPoint128.Q128
            );
            position.token1Amount += FullMath.mulDiv(
                feeGrowthInside1X128 - computation.feeGrowthInside1LastX128, liquidity, FixedPoint128.Q128
            );
        }

        // Token in LP position
        if (computation.tick < tickLower) {
            position.token0Amount += SqrtPriceMath.getAmount0Delta(
                TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
            );
        } else if (computation.tick < tickUpper) {
            position.token0Amount += SqrtPriceMath.getAmount0Delta(
                computation.sqrtPriceX96, TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
            );
            position.token1Amount += SqrtPriceMath.getAmount1Delta(
                TickMath.getSqrtPriceAtTick(tickLower), computation.sqrtPriceX96, liquidity, false
            );
        } else {
            position.token1Amount += SqrtPriceMath.getAmount1Delta(
                TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
            );
        }
    }
}
