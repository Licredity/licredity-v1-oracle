// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";
import {LicredityChainlinkOracle} from "src/LicredityChainlinkOracle.sol";
import {Deployers} from "./Deployers.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IPositionManager} from "src/interfaces/IPositionManager.sol";

contract LicredityChainlinkOracleTest is Deployers {
    error NotSupportedFungible();

    PoolId public mockPoolId;
    address public licredityFungible;
    LicredityChainlinkOracle public oracle;

    function setUp() public {
        deployLicredity();
        deployUniswapV4Pool();
        deployMockChainlinkOracle();

        mockPoolId = PoolId.wrap(bytes32(hex"01"));
        oracle = new LicredityChainlinkOracle(
            address(licredity),
            address(this),
            mockPoolId,
            IPoolManager(address(uniswapV4Mock)),
            IPositionManager(address(0))
        );

        licredityFungible = address(licredity);
    }

    modifier asLicredity() {
        vm.startPrank(address(licredity));
        _;
        vm.stopPrank();
    }

    function getOraclePriceFromFFI(uint256 lastPrice, uint256 nowPrice, uint256 skipTime) public returns (uint256) {
        string[] memory inputs = new string[](6);
        inputs[0] = "uv";
        inputs[1] = "run";
        inputs[2] = "test/python-scripts/ema_update.py";
        inputs[3] = vm.toString(lastPrice);
        inputs[4] = vm.toString(nowPrice);
        inputs[5] = vm.toString(skipTime);

        bytes memory res = vm.ffi(inputs);
        return vm.parseUint(string(res));
    }

    function test_oracleUpdate_upperLimit(uint88 interPrice) public asLicredity {
        skip(1);

        // inter price in block will not update ema price
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, interPrice);
        oracle.update();

        // update price = 10
        uint160 nowSqrtPrice = 250541448375047946302209916928;
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, nowSqrtPrice);

        oracle.update();
        uint256 emaPriceFromFFI = getOraclePriceFromFFI(1 << 96, nowSqrtPrice, 1);

        assertApproxEqAbsDecimal(oracle.getBasePrice(), emaPriceFromFFI, 1e4, 18);
    }

    function test_oracleUpdate_maxTime() public asLicredity {
        skip(6000);

        uint160 nowSqrtPrice = 79843750678802117044226490368; // update price = 1.0156
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, nowSqrtPrice);
        oracle.update();

        uint256 emaPriceFromFFI = getOraclePriceFromFFI(1 << 96, nowSqrtPrice, 6000);
        assertApproxEqAbsDecimal(oracle.getBasePrice(), emaPriceFromFFI, 1e4, 18);
    }

    function test_oracleUpdate_normal() public asLicredity {
        skip(42);
        uint160 nowSqrtPrice = 79346915759800263220867891200; // update price = 1.003
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, nowSqrtPrice);
        oracle.update();

        uint256 emaPriceFromFFI = getOraclePriceFromFFI(1 << 96, nowSqrtPrice, 42);
        assertApproxEqAbsDecimal(oracle.getBasePrice(), emaPriceFromFFI, 1e4, 18);
    }

    function test_oracleUpdate_multiple() public asLicredity {
        skip(42);

        uint160 nowSqrtPrice = 79346915759800263220867891200; // update price = 1.003
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, nowSqrtPrice);
        oracle.update();

        uint256 emaPriceFromFFI = getOraclePriceFromFFI(1 << 96, nowSqrtPrice, 42);
        assertApproxEqAbsDecimal(oracle.getBasePrice(), emaPriceFromFFI, 1e4, 18);

        skip(6000);
        nowSqrtPrice = 79843750678802117044226490368; // update price = 1.0156
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, nowSqrtPrice);
        oracle.update();

        emaPriceFromFFI = getOraclePriceFromFFI(oracle.lastPriceX96(), nowSqrtPrice, 6000);
        assertApproxEqAbsDecimal(oracle.getBasePrice(), emaPriceFromFFI, 1e4, 18);
    }

    function test_quoteNonExistToken(address asset, uint256 amount) public {
        vm.assume(asset != licredityFungible);
        vm.expectRevert(NotSupportedFungible.selector);
        oracle.quoteFungible(asset, amount);
    }

    function test_quoteFungibleDebtToken(uint256 amount) public {
        (uint256 value, uint256 marginRequirement) = oracle.quoteFungible(licredityFungible, amount);
        assertEq(value, amount);
        assertEq(marginRequirement, 0);
    }

    function test_quoteFungibleEthUsd() public {
        oracle.updateFungibleFeedsConfig(address(usd), 1000, AggregatorV3Interface(address(0)), ethUSD);
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, 1 << 96);

        (uint256 value, uint256 marginRequirement) = oracle.quoteFungible(address(usd), 262341076816);

        assertEq(value, 1 ether);
        assertEq(marginRequirement, 0.1 ether);
    }

    function test_quoteFungibleBtcEth() public {
        oracle.updateFungibleFeedsConfig(address(btc), 100, btcETH, AggregatorV3Interface(address(0)));
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, 1 << 96);

        (uint256 value, uint256 marginRequirement) = oracle.quoteFungible(address(btc), 1e8);
        assertEq(value, 40446685000000000000);
        assertEq(marginRequirement, 40446685000000000000 / 100);
    }
}
