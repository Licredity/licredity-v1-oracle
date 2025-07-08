// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import {PoolId} from "v4-core/types/PoolId.sol";
// import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
// import {Extsload} from "v4-core/Extsload.sol";

// contract UniswapV4PoolMock is Extsload {
//     function setPoolIdSqrtPriceX96(PoolId poolId, uint160 sqrtPriceX96) public {
//         bytes32 stateSlot = StateLibrary._getPoolStateSlot(poolId);

//         assembly ("memory-safe") {
//             sstore(stateSlot, sqrtPriceX96)
//         }
//     }
// }
