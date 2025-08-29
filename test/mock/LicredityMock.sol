// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Extsload} from "@uniswap-v4-core/Extsload.sol";

contract LicredityMock is Extsload {
    uint256 private constant POOL_MANAGER_OFFSET = 5;
    uint256 public constant CURRENCY0_OFFSET = 13;

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function setPoolManagerAndPoolId(address _poolManager, address _currency0) public {
        assembly ("memory-safe") {
            sstore(POOL_MANAGER_OFFSET, _poolManager)
            sstore(CURRENCY0_OFFSET, _currency0)
        }
    }
}
