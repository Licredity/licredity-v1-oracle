// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @dev Modified from
/// https://github.com/Uniswap/v4-periphery/blob/main/src/libraries/PositionInfoLibrary.sol
type PositionInfo is uint256;

using PositionInfoLibrary for PositionInfo global;

library PositionInfoLibrary {
    uint8 internal constant TICK_LOWER_OFFSET = 8;
    uint8 internal constant TICK_UPPER_OFFSET = 32;

    function tickLower(PositionInfo info) internal pure returns (int24 _tickLower) {
        assembly ("memory-safe") {
            _tickLower := signextend(2, shr(TICK_LOWER_OFFSET, info))
        }
    }

    function tickUpper(PositionInfo info) internal pure returns (int24 _tickUpper) {
        assembly ("memory-safe") {
            _tickUpper := signextend(2, shr(TICK_UPPER_OFFSET, info))
        }
    }
}
