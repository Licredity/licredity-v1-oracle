// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title NonFungible
/// @notice Represents a non-fungible
/// @dev 160 bits token address | 32 bits empty | 64 bits token ID
type NonFungible is bytes32;

using NonFungibleLibrary for NonFungible global;

/// @title NonFungibleLibrary
/// @notice Library for managing non-fungibles
library NonFungibleLibrary {
    /// @notice Gets the token address of a non-fungible
    /// @param self The non-fungible to get the token address of
    /// @return _tokenAddress The token address of the non-fungible
    function tokenAddress(NonFungible self) internal pure returns (address _tokenAddress) {
        assembly ("memory-safe") {
            _tokenAddress := shr(96, self)
        }
    }

    /// @notice Gets the token ID of a non-fungible
    /// @param self The non-fungible to get the token ID of
    /// @return _tokenId The token ID of the non-fungible
    function tokenId(NonFungible self) internal pure returns (uint256 _tokenId) {
        assembly ("memory-safe") {
            _tokenId := and(self, 0xffffffffffffffff)
        }
    }
}
