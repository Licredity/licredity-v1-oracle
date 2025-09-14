// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolId} from "@uniswap-v4-core/types/PoolId.sol";

contract LicredityMock {
    address public poolManager;
    PoolId public poolId;

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function setPoolManagerAndPoolId(address _poolManager, PoolId _poolId) public {
        poolManager = _poolManager;
        poolId = _poolId;
    }
}
