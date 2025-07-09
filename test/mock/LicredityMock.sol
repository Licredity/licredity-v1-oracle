// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolId} from "@uniswap-v4-core/types/PoolId.sol";
import {Extsload} from "@uniswap-v4-core/Extsload.sol";

contract LicredityMock is Extsload {
    uint256 private constant POOL_MANAGER_OFFSET = 5;
    uint256 private constant POOL_ID_OFFSET = 14;

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function setPoolManagerAndPoolId(address _poolManager, PoolId _poolId) public {
        assembly ("memory-safe") {
            sstore(POOL_MANAGER_OFFSET, _poolManager)
            sstore(POOL_ID_OFFSET, _poolId)
        }
    }
}
