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
}
