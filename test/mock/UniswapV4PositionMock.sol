// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPositionManager} from "src/modules/uniswap/v4/interfaces/IPositionManager.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {PositionInfo} from "src/modules/uniswap/v4/types/PositionInfo.sol";

contract UniswapV4PositionMock is IPositionManager {
    IPoolManager public immutable poolManager;
    PoolKey internal poolKey;
    PositionInfo internal positionInfo;

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    function setPoolAndPositionInfo(uint256, PoolKey memory _poolKey, PositionInfo _positionInfo) external {
        poolKey = _poolKey;
        positionInfo = _positionInfo;
    }

    /// @inheritdoc IPositionManager
    function getPoolAndPositionInfo(uint256) external view override returns (PoolKey memory, PositionInfo) {
        return (poolKey, positionInfo);
    }
}
