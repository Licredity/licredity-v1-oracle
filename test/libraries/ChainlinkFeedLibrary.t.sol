// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";
import {ChainlinkFeedLibrary} from "src/libraries/ChainlinkFeedLibrary.sol";
import {AggregatorV3Interface} from "src/interfaces/external/AggregatorV3Interface.sol";

contract ChainlinkFeedLibraryWrapper {
    function getPrice(AggregatorV3Interface feed, uint256 maxStaleness) external view returns (uint256 price) {
        return ChainlinkFeedLibrary.getPrice(feed, maxStaleness);
    }
}

contract ChainlinkFeedLibraryTest is Test {
    address internal constant MOCK_FEED = address(0xFEED);
    ChainlinkFeedLibraryWrapper internal wrapper;

    function setUp() public {
        wrapper = new ChainlinkFeedLibraryWrapper();
    }

    function test_getPrice_unacceptsStale(uint256 updateDelta) public {
        vm.warp(block.timestamp + 10 days);
        updateDelta = bound(updateDelta, 0, 10 days);
        // Mock the Chainlink feed to return a price but with stale timestamp (e.g., updated 1 day ago)
        // In a secure implementation, this should revert due to staleness, but here it does not
        vm.mockCall(
            MOCK_FEED,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(uint80(1), int256(100e8), uint256(0), block.timestamp - updateDelta, uint80(1))
        );

        if (updateDelta < 1 days) {
            // If the update delta is less than 1 day, we expect the price to be returned
            uint256 price = wrapper.getPrice(AggregatorV3Interface(MOCK_FEED), 1 days);
            assertEq(price, 100e8);
        } else {
            // If the update delta is more than 1 day, we expect a revert due to staleness
            vm.expectRevert(ChainlinkFeedLibrary.FeedOutage.selector);
            wrapper.getPrice(AggregatorV3Interface(MOCK_FEED), 1 days);
        }
    }
}
