// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20Minimal} from "../interfaces/IERC20Minimal.sol";

type Fungible is address;

using {equals as ==} for Fungible global;
using FungibleLibrary for Fungible global;

function equals(Fungible x, Fungible y) pure returns (bool) {
    return Fungible.unwrap(x) == Fungible.unwrap(y);
}

library FungibleLibrary {
    Fungible public constant NATIVE = Fungible.wrap(address(0));

    function decimals(Fungible fungible) internal view returns (uint8) {
        if (fungible == NATIVE) {
            return 18;
        }
        return IERC20Minimal(Fungible.unwrap(fungible)).decimals();
    }
}
