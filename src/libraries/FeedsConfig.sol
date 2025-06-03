// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";

struct FeedsConfig {
    uint8 debtTokenDecimals;
    AggregatorV3Interface baseFeed;
    AggregatorV3Interface quoteFeed;
}
