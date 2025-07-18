// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";
import {PoolAddressLibrary} from "src/modules/uniswap/v3/libraries/PoolAddress.sol";
import {UniswapV3Module, UniswapV3ModuleLibrary} from "src/modules/uniswap/v3/UniswapV3Module.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";
import {Fuzzers} from "@uniswap-v4-core/test/Fuzzers.sol";
import {PoolKey as UniswapV4PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {UniswapV3NonfungiblePositionManagerMock, PositionDataMock} from "../mock/UniswapV3PositionMock.sol";
import {Deployers} from "test/utils/Deployers.sol";
import {
    V3Helper, IUniswapV3Pool, IUniswapV3MintCallback, IUniswapV3SwapCallback
} from "test/utils/UniswapV3Helper.sol";
import {INonfungiblePositionManager} from "src/modules/uniswap/v3/interfaces/INonfungiblePositionManager.sol";
import {IHooks} from "@uniswap-v4-core/interfaces/IHooks.sol";

abstract contract V3Fuzzer is V3Helper, Deployers, Fuzzers, IUniswapV3MintCallback, IUniswapV3SwapCallback {
    PositionDataMock internal position;

    function initPools(uint24 fee, int24 tickSpacing, int256 sqrtPriceX96seed)
        internal
        returns (IUniswapV3Pool v3Pool, UniswapV4PoolKey memory key_, uint160 sqrtPriceX96)
    {
        fee = uint24(bound(fee, 0, 999999));
        tickSpacing = int24(bound(tickSpacing, 1, 16383));
        // v3 pools don't allow overwriting existing fees, 500, 3000, 10000 are set by default in the constructor
        if (fee == 500) tickSpacing = 10;
        else if (fee == 3000) tickSpacing = 60;
        else if (fee == 10000) tickSpacing = 200;
        else v3Factory.enableFeeAmount(fee, tickSpacing);

        sqrtPriceX96 = createRandomSqrtPriceX96(tickSpacing, sqrtPriceX96seed);

        v3Pool = IUniswapV3Pool(v3Factory.createPool(Currency.unwrap(currency0), Currency.unwrap(currency1), fee));
        key_ = UniswapV4PoolKey(currency0, currency1, fee, tickSpacing, IHooks(address(0)));

        v3Pool.initialize(sqrtPriceX96);
    }

    function addLiquidity(
        IUniswapV3Pool v3Pool,
        UniswapV4PoolKey memory key_,
        uint160 sqrtPriceX96,
        int24 lowerTickUnsanitized,
        int24 upperTickUnsanitized,
        int256 liquidityDeltaUnbound
    ) internal returns (IPoolManager.ModifyLiquidityParams memory v4LiquidityParams) {
        v4LiquidityParams = IPoolManager.ModifyLiquidityParams({
            tickLower: lowerTickUnsanitized,
            tickUpper: upperTickUnsanitized,
            liquidityDelta: liquidityDeltaUnbound,
            salt: 0
        });

        v4LiquidityParams = createFuzzyLiquidityParams(key_, v4LiquidityParams, sqrtPriceX96);

        v3Pool.mint(
            address(this),
            v4LiquidityParams.tickLower,
            v4LiquidityParams.tickUpper,
            uint128(int128(v4LiquidityParams.liquidityDelta)),
            ""
        );

        position = PositionDataMock({
            nonce: 0,
            operator: address(0),
            token0: Currency.unwrap(currency0),
            token1: Currency.unwrap(currency1),
            fee: v3Pool.fee(),
            tickLower: v4LiquidityParams.tickLower,
            tickUpper: v4LiquidityParams.tickUpper,
            liquidity: uint128(int128(v4LiquidityParams.liquidityDelta)),
            feeGrowthInside0LastX128: 0,
            feeGrowthInside1LastX128: 0,
            tokensOwed0: 0,
            tokensOwed1: 0
        });
    }

    function swap(IUniswapV3Pool pool, bool zeroForOne, int128 amountSpecified)
        internal
        returns (int256 amount0Delta, int256 amount1Delta)
    {
        if (amountSpecified == 0) amountSpecified = 1;
        if (amountSpecified == type(int128).min) amountSpecified = type(int128).min + 1;
        // v3 swap
        (amount0Delta, amount1Delta) = pool.swap(
            // invert amountSpecified because v3 swaps use inverted signs
            address(this),
            zeroForOne,
            amountSpecified * -1,
            zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT,
            ""
        );
    }

    function positions(uint256)
        external
        view
        returns (
            uint96 nonce,
            address operator,
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
        )
    {
        return (
            position.nonce,
            position.operator,
            position.token0,
            position.token1,
            position.fee,
            position.tickLower,
            position.tickUpper,
            position.liquidity,
            position.feeGrowthInside0LastX128,
            position.feeGrowthInside1LastX128,
            position.tokensOwed0,
            position.tokensOwed1
        );
    }

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata) external {
        currency0.transfer(msg.sender, amount0Owed);
        currency1.transfer(msg.sender, amount1Owed);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        if (amount0Delta > 0) currency0.transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) currency1.transfer(msg.sender, uint256(amount1Delta));
    }
}

contract UniswapV3PoolAddressTest is Test, V3Fuzzer {
    using PoolAddressLibrary for address;

    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
    UniswapV3Module internal module;

    function setUp() public override {
        super.setUp();
        deployMintAndApprove2Currencies();

        module.positionManager = INonfungiblePositionManager(address(this));
        module.poolFactory = address(v3Factory);
    }

    function computeAddress(address factory, PoolKey memory key) internal pure returns (address pool) {
        // require(key.token0 < key.token1);
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encode(key.token0, key.token1, key.fee)),
                            POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }

    function test_computeAddress(address factory, PoolKey memory key) public pure {
        assertEq(factory.computeAddress(key.token0, key.token1, key.fee), computeAddress(factory, key));
    }

    function test_computeAddress_array(address factory, PoolKey[] memory keys) public pure {
        for (uint256 i = 0; i < keys.length; i++) {
            PoolKey memory key = keys[i];
            assertEq(factory.computeAddress(key.token0, key.token1, key.fee), computeAddress(factory, key));
        }
    }

    function test_getPositionData(PositionDataMock memory postionMock) public {
        UniswapV3NonfungiblePositionManagerMock target = new UniswapV3NonfungiblePositionManagerMock();

        target.setReturnData(postionMock);

        UniswapV3ModuleLibrary.PositionData memory positionData = UniswapV3ModuleLibrary._getPositionData(target, 1);

        assertEq(positionData.token0, postionMock.token0);
        assertEq(positionData.token1, postionMock.token1);
        assertEq(positionData.fee, postionMock.fee);
        assertEq(positionData.tickLower, postionMock.tickLower);
        assertEq(positionData.tickUpper, postionMock.tickUpper);
        assertEq(positionData.liquidity, postionMock.liquidity);
        assertEq(positionData.feeGrowthInside0LastX128, postionMock.feeGrowthInside0LastX128);
        assertEq(positionData.feeGrowthInside1LastX128, postionMock.feeGrowthInside1LastX128);
        assertEq(positionData.tokensOwed0, postionMock.tokensOwed0);
        assertEq(positionData.tokensOwed1, postionMock.tokensOwed1);
    }

    function test_getPositionValue_Liquidity(
        uint24 feeSeed,
        int24 tickSpacingSeed,
        int24 lowerTickUnsanitized,
        int24 upperTickUnsanitized,
        int256 liquidityDeltaUnbound,
        int256 sqrtPriceX96seed
    ) public {
        (IUniswapV3Pool pool, UniswapV4PoolKey memory key, uint160 sqrtPriceX96) =
            initPools(feeSeed, tickSpacingSeed, sqrtPriceX96seed);

        module.setPool(address(pool), true);

        IPoolManager.ModifyLiquidityParams memory v4LiquidityParams =
            addLiquidity(pool, key, sqrtPriceX96, lowerTickUnsanitized, upperTickUnsanitized, liquidityDeltaUnbound);

        (, uint256 amount0,, uint256 amount1) = module.getPositionValue(1);

        pool.burn(
            v4LiquidityParams.tickLower, v4LiquidityParams.tickUpper, uint128(int128(v4LiquidityParams.liquidityDelta))
        );

        bytes32 positionKey =
            keccak256(abi.encodePacked(address(this), v4LiquidityParams.tickLower, v4LiquidityParams.tickUpper));
        (,,, uint128 tokensOwed0, uint128 tokensOwed1) = pool.positions(positionKey);

        assertEq(amount0, uint128(tokensOwed0));
        assertEq(amount1, uint128(tokensOwed1));
    }

    function test_getPositionValue_Swap(
        uint24 feeSeed,
        int24 tickSpacingSeed,
        int24 lowerTickUnsanitized,
        int24 upperTickUnsanitized,
        int256 liquidityDeltaUnbound,
        int256 sqrtPriceX96seed,
        int128 swapAmount,
        bool zeroForOne
    ) public {
        (IUniswapV3Pool pool, UniswapV4PoolKey memory key, uint160 sqrtPriceX96) =
            initPools(feeSeed, tickSpacingSeed, sqrtPriceX96seed);

        module.setPool(address(pool), true);

        IPoolManager.ModifyLiquidityParams memory v4LiquidityParams =
            addLiquidity(pool, key, sqrtPriceX96, lowerTickUnsanitized, upperTickUnsanitized, liquidityDeltaUnbound);

        swap(pool, zeroForOne, swapAmount);

        (, uint256 amount0,, uint256 amount1) = module.getPositionValue(1);

        (uint256 burnAmount0, uint256 burnAmount1) = pool.burn(
            v4LiquidityParams.tickLower, v4LiquidityParams.tickUpper, uint128(int128(v4LiquidityParams.liquidityDelta))
        );

        // Only check tokensOwed not overflow
        if (burnAmount0 < type(uint128).max && burnAmount1 < type(uint128).max) {
            bytes32 positionKey =
                keccak256(abi.encodePacked(address(this), v4LiquidityParams.tickLower, v4LiquidityParams.tickUpper));

            (,,, uint128 tokensOwed0, uint128 tokensOwed1) = pool.positions(positionKey);
            assertEq(amount0, uint128(tokensOwed0));
            assertEq(amount1, uint128(tokensOwed1));
        }
    }
}
