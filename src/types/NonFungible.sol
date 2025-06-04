// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC721} from "forge-std/interfaces/IERC721.sol";

/// @dev An 'address' token address and a 'uint96' token ID, packed into a single 'bytes32' value
type NonFungible is bytes32;

using NonFungibleLibrary for NonFungible global;

/// @title NonFungibleLibrary
/// @notice Library for managing non-fungibles
library NonFungibleLibrary {
    /// @notice Transfer non-fungible to recipient
    /// @param self The non-fungible to transfer
    /// @param recipient The address to transfer the non-fungible to
    function transfer(NonFungible self, address recipient) internal {
        address tokenAddress;
        uint256 tokenId;
        assembly ("memory-safe") {
            tokenAddress := shr(96, self)
            tokenId := and(self, sub(shl(96, 1), 1))
        }

        IERC721(tokenAddress).safeTransferFrom(address(this), recipient, tokenId);
    }

    /// @notice Get the owner of a non-fungible
    /// @param self The non-fungible to get the owner of
    /// @return address The owner of the non-fungible
    function owner(NonFungible self) internal view returns (address) {
        address tokenAddress;
        uint256 tokenId;
        assembly ("memory-safe") {
            tokenAddress := shr(96, self)
            tokenId := and(self, sub(shl(96, 1), 1))
        }

        return IERC721(tokenAddress).ownerOf(tokenId);
    }
}
