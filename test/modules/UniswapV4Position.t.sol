// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IHooks} from "@uniswap-v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {SafeCast} from "@uniswap-v4-core/libraries/SafeCast.sol";
import {Fuzzers} from "@uniswap-v4-core/test/Fuzzers.sol";
import {BalanceDelta} from "@uniswap-v4-core/types/BalanceDelta.sol";
import {PoolId} from "@uniswap-v4-core/types/PoolId.sol";
import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {PoolSwapTest} from "@uniswap-v4-core/test/PoolSwapTest.sol";
import {IPositionManager} from "src/modules/uniswap/v4/interfaces/IPositionManager.sol";
import {PositionInfo} from "src/modules/uniswap/v4/types/PositionInfo.sol";
import {UniswapV4Module} from "src/modules/uniswap/v4/UniswapV4Module.sol";
import {Deployers} from "test/utils/Deployers.sol";

contract UniswapV4ModuleTest is Deployers, Fuzzers {
    uint160 public constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    uint256 internal constant MASK_UPPER_200_BITS = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000000000;
    uint24 internal constant MASK_24_BITS = 0xFFFFFF;
    uint8 internal constant TICK_LOWER_OFFSET = 8;
    uint8 internal constant TICK_UPPER_OFFSET = 32;

    PoolKey simpleKey; // vanilla pool key
    PoolId simplePoolId; // id for vanilla pool key
    UniswapV4Module state;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        (simpleKey, simplePoolId) = initPool(currency0, currency1, IHooks(address(0)), 3000, int24(1), SQRT_PRICE_1_1);
        state.poolManager = v4PoolManager;
        state.positionManager = IPositionManager(address(modifyLiquidityRouter));
        state.whitelistedPools[simplePoolId] = true;
    }

    function getPositionInfo(PoolKey memory _poolKey, int24 _tickLower, int24 _tickUpper)
        internal
        pure
        returns (PositionInfo info)
    {
        bytes25 _poolId = bytes25(PoolId.unwrap(_poolKey.toId()));
        assembly {
            info :=
                or(
                    or(and(MASK_UPPER_200_BITS, _poolId), shl(TICK_UPPER_OFFSET, and(MASK_24_BITS, _tickUpper))),
                    shl(TICK_LOWER_OFFSET, and(MASK_24_BITS, _tickLower))
                )
        }
    }

    function test_fuzz_position_Liquidity(IPoolManager.ModifyLiquidityParams memory paramSeed) public {
        IPoolManager.ModifyLiquidityParams memory params =
            createFuzzyLiquidityParams(simpleKey, paramSeed, SQRT_PRICE_1_1);
        params.salt = bytes32(uint256(1));

        BalanceDelta delta = modifyLiquidityRouter.modifyLiquidity(simpleKey, params, hex"");
        PositionInfo positionInfo = getPositionInfo(simpleKey, params.tickLower, params.tickUpper);

        vm.mockCall(
            address(modifyLiquidityRouter),
            abi.encodeWithSelector(IPositionManager.getPoolAndPositionInfo.selector),
            abi.encode(simpleKey, positionInfo)
        );

        (, uint256 amount0,, uint256 amount1) = state.getPositionValue(uint256(1));

        assertApproxEqAbs(amount0, uint128(-delta.amount0()), 1);
        assertApproxEqAbs(amount1, uint128(-delta.amount1()), 1);
    }

    function test_fuzz_position_Swap(
        IPoolManager.ModifyLiquidityParams memory paramSeed,
        bool zeroForOne,
        int128 amountSpecified
    ) public {
        if (amountSpecified == 0) amountSpecified = 1;
        if (amountSpecified == type(int128).min) amountSpecified = type(int128).min + 1;

        IPoolManager.ModifyLiquidityParams memory params =
            createFuzzyLiquidityParams(simpleKey, paramSeed, SQRT_PRICE_1_1);

        params.salt = bytes32(uint256(1));
        modifyLiquidityRouter.modifyLiquidity(simpleKey, params, hex"");

        PositionInfo positionInfo = getPositionInfo(simpleKey, params.tickLower, params.tickUpper);

        IPoolManager.SwapParams memory swapParams = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
        });

        PoolSwapTest.TestSettings memory testSettings =
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

        try swapRouter.swap(simpleKey, swapParams, testSettings, "") {
            vm.mockCall(
                address(modifyLiquidityRouter),
                abi.encodeWithSelector(IPositionManager.getPoolAndPositionInfo.selector),
                abi.encode(simpleKey, positionInfo)
            );

            (, uint256 amount0,, uint256 amount1) = state.getPositionValue(uint256(1));

            if (amount0 > 0 || amount1 > 0) {
                params.liquidityDelta = -params.liquidityDelta;
                try modifyLiquidityRouter.modifyLiquidity(simpleKey, params, hex"") returns (BalanceDelta _delta) {
                    assertEq(amount0, uint128(_delta.amount0()));
                    assertEq(amount1, uint128(_delta.amount1()));
                } catch (bytes memory reason) {
                    assertEq(bytes4(reason), SafeCast.SafeCastOverflow.selector);
                }
            }
        } catch (bytes memory reason) {
            assertEq(bytes4(reason), SafeCast.SafeCastOverflow.selector);
        }
    }
}
