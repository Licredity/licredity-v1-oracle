// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Fungible} from "src/types/Fungible.sol";

struct PositionValue {
    Fungible token0;
    uint256 token0Amount;
    Fungible token1;
    uint256 token1Amount;
}
