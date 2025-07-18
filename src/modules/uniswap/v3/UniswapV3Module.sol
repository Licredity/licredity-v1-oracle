// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {FixedPoint128} from "@uniswap-v4-core/libraries/FixedPoint128.sol";
import {FullMath} from "@uniswap-v4-core/libraries/FullMath.sol";
import {SqrtPriceMath} from "@uniswap-v4-core/libraries/SqrtPriceMath.sol";
import {TickMath} from "@uniswap-v4-core/libraries/TickMath.sol";
import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Pool} from "./interfaces/IUniswapV3Pool.sol";
import {PoolAddressLibrary} from "./libraries/PoolAddress.sol";

/// @title UniswapV3Module
/// @notice Represents a Uniswap V3 module
struct UniswapV3Module {
    address poolFactory;
    INonfungiblePositionManager positionManager;
    mapping(address poolAddress => bool enabled) whitelistedPools;
}

using UniswapV3ModuleLibrary for UniswapV3Module global;

/// @title UniswapV3ModuleLibrary
/// @notice Library for managing Uniswap V3 modules
library UniswapV3ModuleLibrary {
    struct PositionData {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    error AlreadyInitialized();

    /// @notice Initialize the module
    /// @param self The module to initialize
    /// @param poolFactory The pool factory
    /// @param positionManager The position manager
    function initialize(UniswapV3Module storage self, address poolFactory, address positionManager) internal {
        require(address(self.poolFactory) == address(0), AlreadyInitialized());

        self.poolFactory = poolFactory;
        self.positionManager = INonfungiblePositionManager(positionManager);
    }

    /// @notice Sets the whitelisted status of a pool
    /// @param self The module to update
    /// @param pool The pool address to set the whitelist status for
    /// @param isWhitelisted Whether the pool is whitelisted
    function setPool(UniswapV3Module storage self, address pool, bool isWhitelisted) internal {
        self.whitelistedPools[pool] = isWhitelisted;
    }

    /// @notice Gets the fungibles and amounts for a given position ID
    /// @param self The module to query
    /// @param tokenId The position ID to get fungibles and amounts for
    /// @return fungible0 The first fungible
    /// @return amount0 The amount of the first fungible
    /// @return fungible1 The second fungible
    /// @return amount1 The amount of the second fungible
    function getPositionValue(UniswapV3Module storage self, uint256 tokenId)
        internal
        view
        returns (Fungible fungible0, uint256 amount0, Fungible fungible1, uint256 amount1)
    {
        PositionData memory positionData = _getPositionData(self.positionManager, tokenId);

        fungible0 = Fungible.wrap(positionData.token0);
        fungible1 = Fungible.wrap(positionData.token1);

        IUniswapV3Pool pool = IUniswapV3Pool(
            PoolAddressLibrary.computeAddress(
                self.poolFactory, positionData.token0, positionData.token1, positionData.fee
            )
        );

        if (self.whitelistedPools[address(pool)]) {
            (uint160 sqrtPriceX96, int24 tickCurrent,,,,,) = pool.slot0();

            // fee growth inside the position
            {
                (uint256 poolFeeGrowthInside0LastX128, uint256 poolFeeGrowthInside1LastX128) =
                    _getFeeGrowthInside(pool, tickCurrent, positionData.tickLower, positionData.tickUpper);

                unchecked {
                    amount0 += FullMath.mulDiv(
                        poolFeeGrowthInside0LastX128 - positionData.feeGrowthInside0LastX128,
                        positionData.liquidity,
                        FixedPoint128.Q128
                    ) + positionData.tokensOwed0;

                    amount1 += FullMath.mulDiv(
                        poolFeeGrowthInside1LastX128 - positionData.feeGrowthInside1LastX128,
                        positionData.liquidity,
                        FixedPoint128.Q128
                    ) + positionData.tokensOwed1;
                }
            }

            // Calculates the principal (currently acting as liquidity) owed to the token owner
            {
                if (tickCurrent < positionData.tickLower) {
                    amount0 += SqrtPriceMath.getAmount0Delta(
                        TickMath.getSqrtPriceAtTick(positionData.tickLower),
                        TickMath.getSqrtPriceAtTick(positionData.tickUpper),
                        positionData.liquidity,
                        false
                    );
                } else if (tickCurrent < positionData.tickUpper) {
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
        }
    }

    function _getFeeGrowthInside(IUniswapV3Pool pool, int24 tickCurrent, int24 tickLower, int24 tickUpper)
        private
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        (,, uint256 lowerFeeGrowthOutside0X128, uint256 lowerFeeGrowthOutside1X128,,,,) = pool.ticks(tickLower);
        (,, uint256 upperFeeGrowthOutside0X128, uint256 upperFeeGrowthOutside1X128,,,,) = pool.ticks(tickUpper);

        unchecked {
            if (tickCurrent < tickLower) {
                feeGrowthInside0X128 = lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
                feeGrowthInside1X128 = lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
            } else if (tickCurrent < tickUpper) {
                uint256 feeGrowthGlobal0X128 = pool.feeGrowthGlobal0X128();
                uint256 feeGrowthGlobal1X128 = pool.feeGrowthGlobal1X128();
                feeGrowthInside0X128 = feeGrowthGlobal0X128 - lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
                feeGrowthInside1X128 = feeGrowthGlobal1X128 - lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
            } else {
                feeGrowthInside0X128 = upperFeeGrowthOutside0X128 - lowerFeeGrowthOutside0X128;
                feeGrowthInside1X128 = upperFeeGrowthOutside1X128 - lowerFeeGrowthOutside1X128;
            }
        }
    }

    function _getPositionData(INonfungiblePositionManager positionManager, uint256 tokenId)
        internal
        view
        returns (PositionData memory positionData)
    {
        assembly ("memory-safe") {
            positionData := mload(0x40)

            mstore(0x00, 0x99fbab88) // 'positions(uint256 tokenId)'
            mstore(0x20, tokenId)

            let success := staticcall(gas(), positionManager, 0x1c, 0x24, 0x00, 0x00)
            if iszero(success) {
                mstore(0x00, 0x444f8dff) // 'getPositionDataError()'
                revert(0x1c, 0x04)
            }

            returndatacopy(positionData, 0x40, 0x140)
            mstore(0x40, add(positionData, 0x140))
        }
    }
}
