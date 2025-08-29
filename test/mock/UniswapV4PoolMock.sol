// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {StateLibrary} from "@uniswap-v4-core/libraries/StateLibrary.sol";
import {PoolId} from "@uniswap-v4-core/types/PoolId.sol";
import {Extsload} from "@uniswap-v4-core/Extsload.sol";

contract UniswapV4PoolMock is Extsload {
    function setPoolIdSqrtPriceX96(PoolId poolId, uint160 sqrtPriceX96) public {
        bytes32 stateSlot = StateLibrary._getPoolStateSlot(poolId);

        assembly ("memory-safe") {
            sstore(stateSlot, sqrtPriceX96)
        }
    }

    function _getPoolId(address licredity, address currency0) internal pure returns (PoolId poolId) {
        assembly ("memory-safe") {
            let memptr := mload(0x40)
            mstore(memptr, currency0) // currency0
            mstore(add(memptr, 0x20), licredity) // currency1
            mstore(add(memptr, 0x40), 100) // fee
            mstore(add(memptr, 0x60), 1) // tickSpacing
            mstore(add(memptr, 0x80), licredity) // hooks
            poolId := keccak256(memptr, 0xa0)

            mstore(0x40, add(memptr, 0xa0)) // update free memory pointer
        }
    }

    function setMockPoolIdSqrtPriceX96(address licredity, address currency0, uint160 sqrtPriceX96) public {
        PoolId poolId = _getPoolId(licredity, currency0);

        bytes32 stateSlot = StateLibrary._getPoolStateSlot(poolId);

        assembly ("memory-safe") {
            sstore(stateSlot, sqrtPriceX96)
        }
    }
}
