// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";
import {LicredityChainlinkOracle} from "src/LicredityChainlinkOracle.sol";
import {Fungible} from "src/types/Fungible.sol";
import {Deployers} from "./Deployers.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IPositionManager} from "src/interfaces/IPositionManager.sol";

contract LicredityChainlinkOracleTest is Deployers {
    PoolId public mockPoolId;
    Fungible public licredityFungible;
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

        licredityFungible = Fungible.wrap(address(licredity));
    }

    modifier asLicredity() {
        vm.startPrank(address(licredity));
        _;
        vm.stopPrank();
    }

    function test_oracleUpdate_upperLimit(uint88 interPrice) public asLicredity {
        skip(1);

        // inter price in block will not update ema price
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, interPrice);
        oracle.update();

        // update price = 10
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, 250541448375047946302209916928);

        oracle.update();
        assertApproxEqAbsDecimal(oracle.emaPrice(), 1015598980022670848, 1e4, 18);
    }

    function test_oracleUpdate_maxTime() public asLicredity {
        skip(6000);
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, 79843750678802117044226490368); // update price = 1.0156
        oracle.update();
        assertApproxEqAbsDecimal(oracle.emaPrice(), 1000000708238904192, 1e4, 18);
    }

    function test_oracleUpdate_normal() public asLicredity {
        skip(42);
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, 79346915759800263220867891200); // update price = 1.003

        oracle.update();
        assertApproxEqAbsDecimal(oracle.emaPrice(), 1002797181459717632, 1e4, 18);
    }

    function test_oracleUpdate_multiple() public asLicredity {
        skip(42);
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, 79346915759800263220867891200); // update price = 1.003

        oracle.update();
        assertApproxEqAbsDecimal(oracle.emaPrice(), 1002797181459717632, 1e4, 18);

        skip(6000);
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, 79843750678802117044226490368); // update price = 1.0156
        oracle.update();
        assertApproxEqAbsDecimal(oracle.emaPrice(), 1002797762706780032, 1e4, 18);
    }

    function test_quoteNonExistToken(address asset, uint256 amount) public view {
        vm.assume(asset != Fungible.unwrap(licredityFungible));
        assertEq(oracle.quoteFungible(Fungible.wrap(asset), amount), 0);
    }

    function test_quoteFungibleDebtToken(uint256 amount) public view {
        assertEq(oracle.quoteFungible(licredityFungible, amount), amount);
    }

    function test_quoteFungibleEthUsd() public {
        oracle.updateFeedsConfig(Fungible.wrap(address(usd)), AggregatorV3Interface(address(0)), ethUSD);

        uint256 quoteFungibleAmount = oracle.quoteFungible(Fungible.wrap(address(usd)), 262341076816);
        assertEq(quoteFungibleAmount, 1 ether);
    }

    function test_quoteFungibleBtcEth() public {
        oracle.updateFeedsConfig(Fungible.wrap(address(btc)), btcETH, AggregatorV3Interface(address(0)));

        uint256 quoteFungibleAmount = oracle.quoteFungible(Fungible.wrap(address(btc)), 1e8);
        assertEq(quoteFungibleAmount, 40446685000000000000);
    }
}
