// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20Minimal} from "../interfaces/IERC20Minimal.sol";

library FungibleLibrary {
    address public constant NATIVE = address(0);

    function decimals(address token) internal view returns (uint8) {
        if (token == NATIVE) {
            return 18;
        }
        return IERC20Minimal(token).decimals();
    }
}
