// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title NonFungible
/// @notice Represents a non-fungible
/// @dev 160 bits token address | 32 bits empty | 64 bits token id
type NonFungible is bytes32;

using NonFungibleLibrary for NonFungible global;

/// @title NonFungibleLibrary
/// @notice Library for managing non-fungibles
library NonFungibleLibrary {
    /// @notice Gets the token of a non-fungible
    /// @param self The non-fungible to get the token of
    /// @return _token The token of the non-fungible
    function token(NonFungible self) internal pure returns (address _token) {
        assembly ("memory-safe") {
            _token := shr(96, self)
        }
    }

    /// @notice Gets the ID of a non-fungible
    /// @param self The non-fungible to get the ID of
    /// @return _id The ID of the non-fungible
    function id(NonFungible self) internal pure returns (uint256 _id) {
        assembly ("memory-safe") {
            _id := and(self, 0xffffffffffffffff)
        }
    }
}
