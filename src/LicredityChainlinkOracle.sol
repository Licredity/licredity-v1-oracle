// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.30;

import {ILicredityChainlinkOracle} from "./interfaces/ILicredityChainlinkOracle.sol";
import {AggregatorV3Interface} from "./interfaces//AggregatorV3Interface.sol";
import {FixedPointMath} from "./libraries/FixedPointMath.sol";

contract LicredityChainlinkOracle is ILicredityChainlinkOracle {
    using FixedPointMath for int256;
    using FixedPointMath for uint256;

    error NotLicredity();
    error NotOwner();

    address public licredity;
    address public owner;

    uint256 public lastPriceX96;
    uint256 public emaPrice;
    uint256 public lastUpdate;

    mapping(address => AggregatorV3Interface[]) public feeds;

    constructor(address licredity_, address owner_) {
        licredity = licredity_;
        owner = owner_;

        lastPriceX96 = 1 << 96;
        emaPrice = 1e18;
        lastUpdate = block.timestamp;
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

    function updateDebtTokenPrice(uint160 sqrtPriceX96) external onlyLicredity {
        // alpha = e ^ -(block.timestamp - lastUpdate)
        int256 power = ((int256(lastUpdate) - int256(block.timestamp)) << 96) / 600;
        uint256 alphaX96 = uint256(power.expWadX96());

        uint256 priceX96 = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> 96;

        // If priceX96 > lastPriceX96 * (1 + 0.015625), priceX96 = lastPriceX96 * (1 + 0.015625)
        // If priceX96 < lastPriceX96 * (1 - 0.015625), priceX96 = lastPriceX96 * (1 - 0.015625)
        // 0.015625 = 1 / (2 ** 6)
        uint256 priceX96Range = lastPriceX96 >> 6;
        priceX96 = priceX96.clamp(lastPriceX96 - priceX96Range, lastPriceX96 + priceX96Range);

        // emaPriceX192 = alpha * priceX96 + (1 - alpha) * lastPriceX96
        uint256 emaPriceX96 = (alphaX96 * priceX96 + (0x1000000000000000000000000 - alphaX96) * lastPriceX96) >> 96;

        // Update lastPriceX96 and emaPrice
        lastPriceX96 = priceX96;
        emaPrice = (emaPriceX96 * 1e18) >> 96;
    }

    function updateFeeds(address asset, AggregatorV3Interface baseFeed, AggregatorV3Interface quoteFeed)
        external
        onlyOwner
    {
        feeds[asset][0] = baseFeed;
        feeds[asset][1] = quoteFeed;

        emit FeedsUpdated(asset, baseFeed, quoteFeed);
    }
}
