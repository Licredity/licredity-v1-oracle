// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title PoolAddressLibrary
/// @notice Library for computing the address of a Uniswap V3 pool given the factory
library PoolAddressLibrary {
    bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    /// @notice Computes the address of a Uniswap V3 pool given the factory, token0, token1, and fee
    /// @param factory The factory
    /// @param token0 The first token
    /// @param token1 The second token
    /// @param fee The fee tier
    /// @return pool The pool address
    /// @dev Tokens must be sorted in ascending order
    function computeAddress(address factory, address token0, address token1, uint24 fee)
        internal
        pure
        returns (address pool)
    {
        assembly ("memory-safe") {
            let m := mload(0x40) // Cache the free memory pointer.

            // 0x00: 0xff (1 bytes)
            // 0x01 - 0x14: factory address (20 bytes)
            // 0x15 - 0x34: salt (32 bytes)
            // 0x35 - 0x54: POOL_INIT_CODE_HASH (32 bytes)
            mstore(0x00, and(token0, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(0x20, and(token1, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(0x40, and(fee, 0xffffff))

            let salt := keccak256(0x00, 0x60)

            mstore8(0x00, 0xff)
            mstore(0x01, shl(96, factory))
            mstore(0x15, salt)
            mstore(0x35, POOL_INIT_CODE_HASH)

            pool := and(keccak256(0x00, 0x55), 0xffffffffffffffffffffffffffffffffffffffff)

            mstore(0x40, m)
        }
    }
}
