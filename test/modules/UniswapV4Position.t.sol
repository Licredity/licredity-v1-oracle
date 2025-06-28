// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Deployers} from "test/Deployers.sol";
import {PositionValue} from "src/types/PositionValue.sol";
import {NonFungible} from "src/types/NonFungible.sol";
import {UniswapV4PositionState} from "src/modules/uniswap/v4/V4Position.sol";
import {PositionInfo} from "src/modules/uniswap/v4/PositionInfo.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUniswapV4PositionManager} from "src/interfaces/external/IUniswapV4PositionManager.sol";
import {Fuzzers} from "v4-core/test/Fuzzers.sol";

contract NonFungibleOracleFuzz is Deployers, Fuzzers {
    uint160 public constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    uint256 internal constant MASK_UPPER_200_BITS = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000000000;
    uint24 internal constant MASK_24_BITS = 0xFFFFFF;
    uint8 internal constant TICK_LOWER_OFFSET = 8;
    uint8 internal constant TICK_UPPER_OFFSET = 32;

    PoolKey simpleKey; // vanilla pool key
    PoolId simplePoolId; // id for vanilla pool key
    UniswapV4PositionState state;

    IUniswapV4PositionManager mockPositionManager =
        IUniswapV4PositionManager(address(0xeA846a10166d59Ee037d1214623749a677bb6a31));

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        (simpleKey, simplePoolId) = initPool(currency0, currency1, IHooks(address(0)), 3000, int24(1), SQRT_PRICE_1_1);
        state.poolManager = v4PoolManager;
        state.positionManager = mockPositionManager;
        state.positionWhitelist[simplePoolId] = true;
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

    // TODO: Mock
    function test_fuzz_addLiquidity(IPoolManager.ModifyLiquidityParams memory paramSeed) public {
        IPoolManager.ModifyLiquidityParams memory params =
            createFuzzyLiquidityParams(simpleKey, paramSeed, SQRT_PRICE_1_1);

        BalanceDelta delta = modifyLiquidityRouter.modifyLiquidity(simpleKey, params, hex"");
        PositionInfo positionInfo = getPositionInfo(simpleKey, params.tickLower, params.tickUpper);

        vm.mockCall(
            address(mockPositionManager),
            abi.encodeWithSelector(IUniswapV4PositionManager.getPoolAndPositionInfo.selector),
            abi.encode(simpleKey, positionInfo)
        );

        PositionValue memory position = state.getPositionValue(NonFungible.wrap(bytes32(uint256(1))));

        if (position.token0Amount != 0) {
            assertApproxEqAbs(position.token0Amount, uint128(-delta.amount0()), 1);
        }

        if (position.token1Amount != 0) {
            assertApproxEqAbs(position.token1Amount, uint128(-delta.amount1()), 1);
        }
    }
}
