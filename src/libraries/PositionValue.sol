// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolId} from "v4-core/types/PoolId.sol";
import {Position} from "v4-core/libraries/Position.sol";
import {PositionInfo} from "../types/PositionInfo.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {FixedPoint128} from "v4-core/libraries/FixedPoint128.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IPositionManager} from "../interfaces/IPositionManager.sol";

library PositionValue {
    using StateLibrary for IPoolManager;

    struct PositionValueState {
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint160 sqrtPriceX96;
        int24 tick;
    }

    function getPositionValue(
        PoolId poolId,
        uint256 id,
        PositionInfo positionInfo,
        IPoolManager poolManager,
        address positionManager
    ) internal view returns (uint256 token0Amount, uint256 token1Amount) {
        PositionValueState memory state;

        int24 tickLower = positionInfo.tickLower();
        int24 tickUpper = positionInfo.tickUpper();

        bytes32 positionId = Position.calculatePositionKey(positionManager, tickLower, tickUpper, bytes32(id));

        // Fee
        uint128 liquidity;
        (liquidity, state.feeGrowthInside0LastX128, state.feeGrowthInside1LastX128) =
            poolManager.getPositionInfo(poolId, positionId);

        (state.sqrtPriceX96, state.tick,,) = poolManager.getSlot0(poolId);

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            poolManager.getFeeGrowthInside(poolId, tickLower, tickUpper);

        unchecked {
            token0Amount +=
                FullMath.mulDiv(feeGrowthInside0X128 - state.feeGrowthInside0LastX128, liquidity, FixedPoint128.Q128);
            token1Amount +=
                FullMath.mulDiv(feeGrowthInside1X128 - state.feeGrowthInside1LastX128, liquidity, FixedPoint128.Q128);
        }

        if (state.tick < tickLower) {
            token0Amount += SqrtPriceMath.getAmount0Delta(
                TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
            );
        } else if (state.tick < tickUpper) {
            token0Amount += SqrtPriceMath.getAmount0Delta(
                state.sqrtPriceX96, TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
            );
            token1Amount += SqrtPriceMath.getAmount1Delta(
                TickMath.getSqrtPriceAtTick(tickLower), state.sqrtPriceX96, liquidity, false
            );
        } else {
            token1Amount += SqrtPriceMath.getAmount1Delta(
                TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
            );
        }
    }
}
