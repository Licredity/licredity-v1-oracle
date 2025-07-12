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

    function setWhitelistToken(UniswapV3Module storage self, address token, bool isWhitelisted) internal {
        self.isWhitelistedToken[token] = isWhitelisted;
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

    function _getPositionData(address positionManager, uint256 tokenId)
        internal
        view
        returns (PositionData memory positionData)
    {
        assembly ("memory-safe") {
            positionData := mload(0x40)

            mstore(0x00, 0x99fbab88)
            mstore(0x20, tokenId)

            let success := staticcall(gas(), positionManager, 0x1c, 0x24, 0x00, 0x00)
            if iszero(success) {
                mstore(0x00, 0x444f8dff) // getPositionDataError()
                revert(0x1c, 0x04)
            }

            returndatacopy(positionData, 0x40, 0x140)
            mstore(0x40, add(positionData, 0x140))
        }
    }

    function getPositionValue(UniswapV3Module storage self, uint256 tokenId)
        internal
        view
        returns (Fungible fungible0, uint256 amount0, Fungible fungible1, uint256 amount1)
    {
        PositionData memory positionData;

        positionData = _getPositionData(address(self.positionManager), tokenId);

        fungible0 = Fungible.wrap(positionData.token0);
        fungible1 = Fungible.wrap(positionData.token1);

        if (self.isWhitelistedToken[positionData.token0] && self.isWhitelistedToken[positionData.token1]) {
            IUniswapV3Pool pool = IUniswapV3Pool(
                self.uniswapV3Factory.computeAddress(positionData.token0, positionData.token1, positionData.fee)
            );

            (uint160 sqrtPriceX96, int24 tickCurrent,,,,,) = pool.slot0();

            // fee growth inside the position
            {
                (uint256 poolFeeGrowthInside0LastX128, uint256 poolFeeGrowthInside1LastX128) =
                    _getFeeGrowthInside(pool, tickCurrent, positionData.tickLower, positionData.tickUpper);

                amount0 = FullMath.mulDiv(
                    positionData.feeGrowthInside0LastX128 - poolFeeGrowthInside0LastX128,
                    positionData.liquidity,
                    FixedPoint128.Q128
                ) + positionData.tokensOwed0;

                amount1 = FullMath.mulDiv(
                    positionData.feeGrowthInside1LastX128 - poolFeeGrowthInside1LastX128,
                    positionData.liquidity,
                    FixedPoint128.Q128
                ) + positionData.tokensOwed1;
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
                        sqrtPriceX96,
                        TickMath.getSqrtPriceAtTick(positionData.tickUpper),
                        positionData.liquidity,
                        false
                    );
                    amount1 += SqrtPriceMath.getAmount1Delta(
                        TickMath.getSqrtPriceAtTick(positionData.tickLower),
                        sqrtPriceX96,
                        positionData.liquidity,
                        false
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
        } else {
            // if the token is not whitelisted
            amount0 = 0;
            amount1 = 0;
        }
    }
}
