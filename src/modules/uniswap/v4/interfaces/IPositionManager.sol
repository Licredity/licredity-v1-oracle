// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {PositionInfo} from "../types/PositionInfo.sol";

/// @dev Modified from
/// https://github.com/Uniswap/v4-periphery/blob/main/src/interfaces/IPositionManager.sol
interface IPositionManager {
    /// @notice Returns the pool key and position info of a position
    /// @param tokenId the ERC721 tokenId
    /// @return poolKey the pool key of the position
    /// @return PositionInfo a uint256 packed value holding information about the position including the range (tickLower, tickUpper)
    function getPoolAndPositionInfo(uint256 tokenId) external view returns (PoolKey memory, PositionInfo);
}
