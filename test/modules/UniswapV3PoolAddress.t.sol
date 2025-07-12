// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {PoolAddressLibrary} from "src/modules/uniswap/v3/libraries/PoolAddress.sol";

contract UniswapV3PoolAddressTest is Test {
    using PoolAddressLibrary for address;

    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    /// @notice Deterministically computes the pool address given the factory and PoolKey
    /// @param factory The Uniswap V3 factory contract address
    /// @param key The PoolKey
    /// @return pool The contract address of the V3 pool
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
}
