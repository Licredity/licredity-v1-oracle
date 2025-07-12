// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library PoolAddressLibrary {
    bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    function computeAddress(address factory, address token0, address token1, uint24 fee)
        internal
        pure
        returns (address pool)
    {
        assembly ("memory-safe") {
            let m := mload(0x40) // Cache the free memory pointer.

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
