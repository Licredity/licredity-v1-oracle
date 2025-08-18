// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {FixedPoint128} from "@uniswap-v4-core/libraries/FixedPoint128.sol";
import {FullMath} from "@uniswap-v4-core/libraries/FullMath.sol";
import {SqrtPriceMath} from "@uniswap-v4-core/libraries/SqrtPriceMath.sol";
import {StateLibrary} from "@uniswap-v4-core/libraries/StateLibrary.sol";
import {TickMath} from "@uniswap-v4-core/libraries/TickMath.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";
import {PoolId} from "@uniswap-v4-core/types/PoolId.sol";
import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {IPositionManager} from "./interfaces/IPositionManager.sol";
import {PositionInfo} from "./types/PositionInfo.sol";

/// @title UniswapV4Module
/// @notice Represents a Uniswap V4 module
struct UniswapV4Module {
    IPoolManager poolManager;
    IPositionManager positionManager;
    mapping(PoolId => bool) whitelistedPools;
}

using UniswapV4ModuleLibrary for UniswapV4Module global;

/// @title UniswapV4ModuleLibrary
/// @notice Library for managing Uniswap V4 modules
library UniswapV4ModuleLibrary {
    struct PositionData {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
    }

    using StateLibrary for IPoolManager;

    error AlreadyInitialized();

    /// @notice Initialize the module
    /// @param self The module to initialize
    /// @param positionManager The position manager
    function initialize(UniswapV4Module storage self, address positionManager) internal {
        require(address(self.poolManager) == address(0), AlreadyInitialized());

        self.poolManager = IPositionManager(positionManager).poolManager();
        self.positionManager = IPositionManager(positionManager);
    }

    /// @notice Sets the whitelisted status of a pool
    /// @param self The module to update
    /// @param poolId The pool ID to set the whitelist status for
    /// @param isWhitelisted Whether the pool is whitelisted
    function setPool(UniswapV4Module storage self, PoolId poolId, bool isWhitelisted) internal {
        self.whitelistedPools[poolId] = isWhitelisted;
    }

    /// @notice Gets the fungibles and amounts for a given position ID
    /// @param self The module to query
    /// @param positionId The position ID to get fungibles and amounts for
    /// @return fungible0 The first fungible
    /// @return amount0 The amount of the first fungible
    /// @return fungible1 The second fungible
    /// @return amount1 The amount of the second fungible
    function getPositionValue(UniswapV4Module storage self, uint256 positionId)
        internal
        view
        returns (Fungible fungible0, uint256 amount0, Fungible fungible1, uint256 amount1)
    {
        IPoolManager poolManager = self.poolManager; // gas saving
        IPositionManager positionManager = self.positionManager; // gas saving

        (PoolKey memory poolKey, PositionInfo positionInfo) = positionManager.getPoolAndPositionInfo(positionId);
        fungible0 = Fungible.wrap(Currency.unwrap(poolKey.currency0));
        fungible1 = Fungible.wrap(Currency.unwrap(poolKey.currency1));

        PoolId poolId = poolKey.toId();
        // short circuit if the pool is not whitelisted
        if (!self.whitelistedPools[poolId]) {
            return (fungible0, 0, fungible1, 0);
        }

        PositionData memory positionData =
            _getPositionData(poolManager, positionManager, poolId, positionId, positionInfo);

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            poolManager.getFeeGrowthInside(poolId, positionData.tickLower, positionData.tickUpper);

        // uncollected fees in the position
        unchecked {
            amount0 += FullMath.mulDiv(
                feeGrowthInside0X128 - positionData.feeGrowthInside0LastX128, positionData.liquidity, FixedPoint128.Q128
            );
            amount1 += FullMath.mulDiv(
                feeGrowthInside1X128 - positionData.feeGrowthInside1LastX128, positionData.liquidity, FixedPoint128.Q128
            );
        }

        (uint160 sqrtPriceX96, int24 tick,,) = poolManager.getSlot0(poolId);

        // liquidity amounts in the position
        if (tick < positionData.tickLower) {
            amount0 += SqrtPriceMath.getAmount0Delta(
                TickMath.getSqrtPriceAtTick(positionData.tickLower),
                TickMath.getSqrtPriceAtTick(positionData.tickUpper),
                positionData.liquidity,
                false
            );
        } else if (tick < positionData.tickUpper) {
            amount0 += SqrtPriceMath.getAmount0Delta(
                sqrtPriceX96, TickMath.getSqrtPriceAtTick(positionData.tickUpper), positionData.liquidity, false
            );
            amount1 += SqrtPriceMath.getAmount1Delta(
                TickMath.getSqrtPriceAtTick(positionData.tickLower), sqrtPriceX96, positionData.liquidity, false
            );
        } else {
            amount1 += SqrtPriceMath.getAmount1Delta(
                TickMath.getSqrtPriceAtTick(positionData.tickLower),
                TickMath.getSqrtPriceAtTick(positionData.tickUpper),
                positionData.liquidity,
                false
            );
        }
    }

    function _getPositionData(
        IPoolManager poolManager,
        IPositionManager positionManager,
        PoolId poolId,
        uint256 positionId,
        PositionInfo positionInfo
    ) internal view returns (PositionData memory positionData) {
        positionData.tickLower = positionInfo.tickLower();
        positionData.tickUpper = positionInfo.tickUpper();

        (positionData.liquidity, positionData.feeGrowthInside0LastX128, positionData.feeGrowthInside1LastX128) =
        poolManager.getPositionInfo(
            poolId, address(positionManager), positionData.tickLower, positionData.tickUpper, bytes32(positionId)
        );
    }
}
