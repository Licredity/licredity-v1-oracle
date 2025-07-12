// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {PoolAddressLibrary} from "./libraries/PoolAddress.sol";
import {FixedPoint128} from "@uniswap-v4-core/libraries/FixedPoint128.sol";
import {FullMath} from "@uniswap-v4-core/libraries/FullMath.sol";
import {TickMath} from "@uniswap-v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "@uniswap-v4-core/libraries/SqrtPriceMath.sol";
import {IUniswapV3Pool} from "./interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";

struct UniswapV3Module {
    address uniswapV3Factory;
    INonfungiblePositionManager positionManager;
    mapping(address token => bool enabled) isWhitelistedToken;
}

using UniswapV3ModuleLibrary for UniswapV3Module global;

library UniswapV3ModuleLibrary {
    using PoolAddressLibrary for address;

    error AlreadyInitialized();

    function initialize(UniswapV3Module storage self, address uniswapV3Factory, address positionManager) internal {
        require(address(self.uniswapV3Factory) == address(0), AlreadyInitialized());

        self.uniswapV3Factory = uniswapV3Factory;
        self.positionManager = INonfungiblePositionManager(positionManager);
    }

    function setWhitelistToken(UniswapV3Module storage self, address token0, address token1, bool isWhitelisted)
        internal
    {
        self.isWhitelistedToken[token0] = isWhitelisted;
        self.isWhitelistedToken[token1] = isWhitelisted;
    }

    function _getFeeGrowthInside(IUniswapV3Pool pool, int24 tickCurrent, int24 tickLower, int24 tickUpper)
        private
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        (,, uint256 lowerFeeGrowthOutside0X128, uint256 lowerFeeGrowthOutside1X128,,,,) = pool.ticks(tickLower);
        (,, uint256 upperFeeGrowthOutside0X128, uint256 upperFeeGrowthOutside1X128,,,,) = pool.ticks(tickUpper);

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

    function getPositionValue(UniswapV3Module storage self, uint256 tokenId)
        internal
        view
        returns (Fungible fungible0, uint256 amount0, Fungible fungible1, uint256 amount1)
    {
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = self.positionManager.positions(tokenId);

        fungible0 = Fungible.wrap(token0);
        fungible1 = Fungible.wrap(token1);

        IUniswapV3Pool pool = IUniswapV3Pool(self.uniswapV3Factory.computeAddress(token0, token1, fee));

        (uint160 sqrtPriceX96, int24 tickCurrent,,,,,) = pool.slot0();

        // fee growth inside the position
        {
            (uint256 poolFeeGrowthInside0LastX128, uint256 poolFeeGrowthInside1LastX128) =
                _getFeeGrowthInside(pool, tickCurrent, tickLower, tickUpper);

            amount0 = FullMath.mulDiv(
                feeGrowthInside0LastX128 - poolFeeGrowthInside0LastX128, liquidity, FixedPoint128.Q128
            ) + tokensOwed0;

            amount1 = FullMath.mulDiv(
                feeGrowthInside1LastX128 - poolFeeGrowthInside1LastX128, liquidity, FixedPoint128.Q128
            ) + tokensOwed1;
        }

        // Calculates the principal (currently acting as liquidity) owed to the token owner
        {
            if (tickCurrent < tickLower) {
                amount0 += SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
                );
            } else if (tickCurrent < tickUpper) {
                amount0 += SqrtPriceMath.getAmount0Delta(
                    sqrtPriceX96, TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
                );
                amount1 += SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtPriceAtTick(tickLower), sqrtPriceX96, liquidity, false
                );
            } else {
                amount1 += SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
                );
            }
        }

        if (self.isWhitelistedToken[token0] && self.isWhitelistedToken[token1]) {} else {
            // if the token is not whitelisted
            amount0 = 0;
            amount1 = 0;
        }
    }
}
