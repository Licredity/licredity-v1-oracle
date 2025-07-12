// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {PoolAddressLibrary} from "src/modules/uniswap/v3/libraries/PoolAddress.sol";
import {UniswapV3Module, UniswapV3ModuleLibrary} from "src/modules/uniswap/v3/UniswapV3Module.sol";
import {UniswapV3NonfungiblePositionManagerMock, PositionDataMock} from "../mock/UniswapV3PositionMock.sol";

contract UniswapV3PoolAddressTest is Test {
    using PoolAddressLibrary for address;

    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
    UniswapV3NonfungiblePositionManagerMock internal target;
    UniswapV3Module internal module;

    function setUp() public {
        target = new UniswapV3NonfungiblePositionManagerMock();
        module.positionManager = target;
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
        target.setReturnData(postionMock);

        UniswapV3ModuleLibrary.PositionData memory positionData = UniswapV3ModuleLibrary._getPositionData(address(target), 1);

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
}
