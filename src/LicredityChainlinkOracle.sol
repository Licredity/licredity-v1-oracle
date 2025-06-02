// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.30;

import {ILicredityChainlinkOracle} from "./interfaces/ILicredityChainlinkOracle.sol";
import {AggregatorV3Interface} from "./interfaces//AggregatorV3Interface.sol";

contract LicredityChainlinkOracle is ILicredityChainlinkOracle {
    error NotLicredity();
    error NotOwner();

    address public licredity;
    address public owner;
    uint256 public emaPrice;

    mapping(address => AggregatorV3Interface[]) public feeds;

    constructor(address licredity_, address owner_) {
        licredity = licredity_;
        owner = owner_;
    }

    modifier onlyLicredity() {
        require(msg.sender == licredity, NotLicredity());
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, NotOwner());
        _;
    }

    function updateOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function peek(address asset, uint256 amount) external view returns (uint256 debtTokenAmount) {}

    function updateDebtTokenPrice(uint160 sqrtPriceX96) external onlyLicredity {}

    function updateFeeds(address asset, AggregatorV3Interface baseFeed, AggregatorV3Interface quoteFeed)
        external
        onlyOwner
    {
        feeds[asset][0] = baseFeed;
        feeds[asset][1] = quoteFeed;

        emit FeedsUpdated(asset, baseFeed, quoteFeed);
    }
}
