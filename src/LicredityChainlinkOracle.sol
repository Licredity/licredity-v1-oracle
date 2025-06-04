// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.30;

import {ILicredityChainlinkOracle} from "./interfaces/ILicredityChainlinkOracle.sol";
import {IERC20Minimal} from "./interfaces/IERC20Minimal.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {Fungible} from "./types/Fungible.sol";
import {NonFungible} from "./types/NonFungible.sol";
import {ChainlinkDataFeedLib} from "./libraries/ChainlinkDataFeedLib.sol";
import {FeedsConfig} from "./libraries/FeedsConfig.sol";
import {FixedPointMath} from "./libraries/FixedPointMath.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

contract LicredityChainlinkOracle is ILicredityChainlinkOracle {
    using FixedPointMath for int256;
    using FixedPointMath for uint256;
    using ChainlinkDataFeedLib for AggregatorV3Interface;
    using StateLibrary for IPoolManager;

    error NotLicredity();
    error NotOwner();

    PoolId public poolId;
    IPoolManager immutable uniswapV4Manager;

    address public licredity;
    address public owner;

    uint256 public lastPriceX96;
    uint256 public currentPriceX96;
    uint256 public emaPrice;
    uint256 public lastUpdateTimeStamp;
    uint256 public currentTimeStamp;

    mapping(Fungible => FeedsConfig) public feeds;

    constructor(address licredity_, address owner_, IPoolManager uniswapV4_, PoolId poolId_) {
        licredity = licredity_;
        owner = owner_;
        uniswapV4Manager = uniswapV4_;
        poolId = poolId_;

        lastUpdateTimeStamp = block.timestamp;
        currentTimeStamp = block.timestamp;

        currentPriceX96 = 1 << 96;
        lastPriceX96 = 1 << 96;
        emaPrice = 1e18;
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

    /// @notice Returns the number of debt tokens that can be exchanged for the assets.
    function quoteFungible(Fungible fungible, uint256 amount) external view returns (uint256 debtTokenAmount) {
        if (fungible == Fungible.wrap(licredity)) {
            debtTokenAmount = amount;
        } else {
            FeedsConfig memory config = feeds[fungible];

            // If asset is token, need to set both baseFeed and quoteFeed of token to zero addresses
            // (scaleFactor * amount) * baseFeed * emaPrice / quoteFeed
            debtTokenAmount = (config.scaleFactor * amount).fullMulDiv(
                emaPrice * config.baseFeed.getPrice(), config.quoteFeed.getPrice() * 1e36
            );
        }
    }

    function update() external onlyLicredity {
        if (block.timestamp != currentTimeStamp) {
            lastUpdateTimeStamp = currentTimeStamp;
            currentTimeStamp = block.timestamp;
            lastPriceX96 = currentPriceX96;
        }

        // TODO: get sqrtPriceX96 from uniswap v4
        (uint160 sqrtPriceX96,,,) = uniswapV4Manager.getSlot0(poolId);

        // alpha = e ^ -(block.timestamp - lastUpdateTimeStamp)
        int256 power = ((int256(lastUpdateTimeStamp) - int256(block.timestamp)) << 96) / 600;
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
        currentPriceX96 = emaPriceX96;
        emaPrice = (emaPriceX96 * 1e18) >> 96;
    }

    function updateFeedsConfig(Fungible asset, AggregatorV3Interface baseFeed, AggregatorV3Interface quoteFeed)
        external
        onlyOwner
    {
        uint8 assetTokenDecimals = asset.decimals();
        uint8 debtTokenDecimals = Fungible.wrap(licredity).decimals();

        uint256 scaleFactor =
            10 ** (18 + quoteFeed.getDecimals() + debtTokenDecimals - baseFeed.getDecimals() - assetTokenDecimals);

        feeds[asset] = FeedsConfig({scaleFactor: scaleFactor, baseFeed: baseFeed, quoteFeed: quoteFeed});

        emit FeedsUpdated(asset, baseFeed, quoteFeed);
    }
}
