// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC721} from "forge-std/interfaces/IERC721.sol";

/// @dev An 'address' token address and a 'uint96' token ID, packed into a single 'bytes32' value
type NonFungible is bytes32;

using NonFungibleLibrary for NonFungible global;

/// @title NonFungibleLibrary
/// @notice Library for managing non-fungibles
library NonFungibleLibrary {
    /// @notice Get the token ID of a non-fungible
    /// @param self The non-fungible to get the token ID of
    function getTokenId(NonFungible self) internal pure returns (uint256) {
        uint256 tokenId;
        assembly ("memory-safe") {
            tokenId := and(self, sub(shl(96, 1), 1))
        }
        return tokenId;
    }

    function getTokenAddress(NonFungible self) internal pure returns (address) {
        address tokenAddress;
        assembly ("memory-safe") {
            tokenAddress := shr(96, self)
        }
        return tokenAddress;
    }
}
