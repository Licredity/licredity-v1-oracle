// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "../interfaces/external/AggregatorV3Interface.sol";

/// @title ChainlinkFeedLibrary
/// @notice Library for interacting with Chainlink feeds
library ChainlinkFeedLibrary {
    error NegativeAnswer();

    /// @notice Gets the latest price from a Chainlink feed
    /// @param feed The Chainlink feed to query
    /// @return price The latest price from the feed
    /// @dev When `feed` is not set (address zero), returns 1
    function getPrice(AggregatorV3Interface feed) internal view returns (uint256 price) {
        if (address(feed) == address(0)) return 1;

        (, int256 answer,,,) = feed.latestRoundData();

        assembly ("memory-safe") {
            // require(answer >= 0, NegativeAnswer());
            if slt(answer, 0) {
                mstore(0x00, 0xfd54c202) // 'NegativeAnswer()'
                revert(0x1c, 0x04)
            }

            price := answer
        }
    }

    /// @notice Gets the number of decimals from a Chainlink feed
    /// @param feed The Chainlink feed to query
    /// @return decimals The number of decimals used by the feed
    /// @dev When `feed` is not set (address zero), returns 0
    function getDecimals(AggregatorV3Interface feed) internal view returns (uint256 decimals) {
        if (address(feed) == address(0)) return 0;

        return feed.decimals();
    }
}
