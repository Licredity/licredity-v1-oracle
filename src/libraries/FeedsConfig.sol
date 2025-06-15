// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";

struct FeedsConfig {
    /// @notice The margin requirement in basis points of asset
    uint24 mrrPips;
    uint256 scaleFactor;
    AggregatorV3Interface baseFeed;
    AggregatorV3Interface quoteFeed;
}
