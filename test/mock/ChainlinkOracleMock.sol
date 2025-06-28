// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "src/interfaces/external/AggregatorV3Interface.sol";

contract ChainlinkOracleMock is AggregatorV3Interface {
    uint8 public decimals;
    string public description;
    uint256 public constant version = 1;
    int256 public answer;

    constructor(uint8 decimals_, string memory description_) {
        decimals = decimals_;
        description = description_;
    }

    function setAnswer(int256 answer_) public {
        answer = answer_;
    }

    function latestRoundData() public view override returns (uint80, int256, uint256, uint256, uint80) {
        return (0, answer, 0, 0, 0);
    }

    function getRoundData(uint80) public view override returns (uint80, int256, uint256, uint256, uint80) {
        return (0, answer, 0, 0, 0);
    }
}
