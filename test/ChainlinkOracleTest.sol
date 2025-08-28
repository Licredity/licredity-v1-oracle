// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {stdMath} from "@forge-std/StdMath.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {PoolId} from "@uniswap-v4-core/types/PoolId.sol";
import {AggregatorV3Interface} from "src/interfaces/external/AggregatorV3Interface.sol";
import {IPositionManager} from "src/modules/uniswap/v4/interfaces/IPositionManager.sol";
import {ChainlinkOracle} from "src/ChainlinkOracle.sol";
import {Deployers} from "./utils/Deployers.sol";

contract ChainlinkOracleTest is Deployers {
    error NotSupportedFungible();

    PoolId public mockPoolId;
    address public licredityFungible;
    ChainlinkOracle public oracle;

    function setUp() public {
        deployLicredity();
        deployUniswapV4MockPool();
        deployMockChainlinkOracle();

        IPoolManager v4Manager = IPoolManager(address(uniswapV4Mock));
        mockPoolId = PoolId.wrap(bytes32(hex"01"));
        licredity.setPoolManagerAndPoolId(address(v4Manager), mockPoolId);
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, 1 << 96);

        deployUniswapV4PositionManagerMock(v4Manager);
        oracle = new ChainlinkOracle(address(licredity), address(this));
        oracle.initializeUniswapV4Module(address(v4PositionManagerMock));

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

        assertApproxEqAbsDecimal(oracle.quotePrice(), emaPriceFromFFI, 1e4, 18);
    }

    function test_oracleUpdate_maxTime() public asLicredity {
        skip(6000);

        uint160 nowSqrtPrice = 79843750678802117044226490368; // update price = 1.0156
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, nowSqrtPrice);
        oracle.update();

        uint256 emaPriceFromFFI = getOraclePriceFromFFI(1 << 96, nowSqrtPrice, 6000);
        assertApproxEqAbsDecimal(oracle.quotePrice(), emaPriceFromFFI, 1e4, 18);
    }

    function test_oracleUpdate_normal() public asLicredity {
        skip(42);
        uint160 nowSqrtPrice = 79346915759800263220867891200; // update price = 1.003
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, nowSqrtPrice);
        oracle.update();

        uint256 emaPriceFromFFI = getOraclePriceFromFFI(1 << 96, nowSqrtPrice, 42);
        assertApproxEqAbsDecimal(oracle.quotePrice(), emaPriceFromFFI, 1e4, 18);
    }

    function test_oracleUpdate_multiple() public asLicredity {
        skip(42);

        uint160 nowSqrtPrice = 79346915759800263220867891200; // update price = 1.003
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, nowSqrtPrice);
        oracle.update();

        uint256 emaPriceFromFFI = getOraclePriceFromFFI(1 << 96, nowSqrtPrice, 42);
        assertApproxEqAbsDecimal(oracle.quotePrice(), emaPriceFromFFI, 1e4, 18);

        skip(6000);
        nowSqrtPrice = 79843750678802117044226490368; // update price = 1.0156
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, nowSqrtPrice);
        oracle.update();

        emaPriceFromFFI = getOraclePriceFromFFI(oracle.lastPriceX96(), nowSqrtPrice, 6000);
        assertApproxEqAbsDecimal(oracle.quotePrice(), emaPriceFromFFI, 1e4, 18);
    }

    struct OralceUpdate {
        uint128 nowPriceX96;
        uint16 skipTime;
    }

    function test_oracleUpdate_fuzz(OralceUpdate[] calldata data) public asLicredity {
        for (uint256 i = 0; i < data.length; i++) {
            uint256 beforePrice = oracle.quotePrice();
            if (data[i].skipTime == 0) {
                skip(1);
            } else {
                skip(data[i].skipTime);
            }
            uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, data[i].nowPriceX96);
            oracle.update();
            uint256 afterPrice = oracle.quotePrice();

            uint256 delta = stdMath.percentDelta(beforePrice, afterPrice);
            assertLt(delta, 0.016625 ether);
        }
    }

    function test_quoteNonExistToken(Fungible[] calldata fungibles, uint256[] calldata amounts) public {
        vm.assume(fungibles.length > 1);
        vm.assume(fungibles.length < amounts.length);
        uint256 debtTokenSum = 0;

        for (uint256 i = 0; i < fungibles.length; i++) {
            if (fungibles[i] == Fungible.wrap(licredityFungible)) {
                debtTokenSum += amounts[i];
            }
        }

        (uint256 value, uint256 marginRequirement) = oracle.quoteFungibles(fungibles, amounts);

        assertEq(value, debtTokenSum);
        assertEq(marginRequirement, 0);
    }

    function test_quoteFungibleDebtToken(uint64[] calldata amounts) public {
        vm.assume(amounts.length < 5);
        uint256 sumAmount;
        Fungible[] memory onlyLicredityFungible = new Fungible[](amounts.length);
        uint256[] memory fungibleAmount = new uint256[](amounts.length);

        for (uint256 i = 0; i < amounts.length; i++) {
            sumAmount += amounts[i];
            onlyLicredityFungible[i] = Fungible.wrap(licredityFungible);
            fungibleAmount[i] = amounts[i];
        }

        (uint256 value, uint256 marginRequirement) = oracle.quoteFungibles(onlyLicredityFungible, fungibleAmount);
        assertEq(value, sumAmount);
        assertEq(marginRequirement, 0);
    }

    function test_quoteFungibleEthUsd() public {
        vm.warp(block.timestamp + 1 days);
        ethUSD.setUpdatedAt(block.timestamp - 1);

        oracle.setFungibleConfig(Fungible.wrap(address(usd)), 100000, AggregatorV3Interface(address(0)), ethUSD);
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, 1 << 96);

        Fungible[] memory fungibles = new Fungible[](1);
        fungibles[0] = Fungible.wrap(address(usd));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 262341076816;

        (uint256 value, uint256 marginRequirement) = oracle.quoteFungibles(fungibles, amounts);

        assertEq(value, 1 ether);
        assertEq(marginRequirement, 0.1 ether);
    }

    function test_quoteFungibleBtcEth() public {
        vm.warp(block.timestamp + 1 days);
        btcETH.setUpdatedAt(block.timestamp - 1);
        oracle.setFungibleConfig(Fungible.wrap(address(btc)), 10000, btcETH, AggregatorV3Interface(address(0)));
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, 1 << 96);

        Fungible[] memory fungibles = new Fungible[](1);
        fungibles[0] = Fungible.wrap(address(btc));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e8;

        (uint256 value, uint256 marginRequirement) = oracle.quoteFungibles(fungibles, amounts);
        assertEq(value, 40446685000000000000);
        assertEq(marginRequirement, 40446685000000000000 / 100);
    }
}
