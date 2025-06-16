// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ChainInfo} from "../libraries/ChainInfo.sol";

/// @title Fungible
/// @notice Represents a fungible
type Fungible is address;

using {equals as ==} for Fungible global;
using FungibleLibrary for Fungible global;

/// @notice Checks whether two fungibles are equal
/// @param x The first fungible to compare
/// @param y The second fungible to compare
function equals(Fungible x, Fungible y) pure returns (bool) {
    return Fungible.unwrap(x) == Fungible.unwrap(y);
}

library FungibleLibrary {
    address public constant NATIVE = address(0);

    /// @notice Gets the decimals of a fungible
    /// @param self The fungible to get decimals of
    /// @return uint8 The number of decimals of the fungible
    function decimals(Fungible self) internal view returns (uint8) {
        return self.isNative() ? ChainInfo.NATIVE_DECIMALS : IERC20(Fungible.unwrap(self)).decimals();
    }

    /// @notice Checks whether a fungible is native to the chain
    /// @param self The fungible to check
    /// @return bool True if the fungible is native, false otherwise
    function isNative(Fungible self) internal pure returns (bool) {
        return Fungible.unwrap(self) == ChainInfo.NATIVE;
    }
}
