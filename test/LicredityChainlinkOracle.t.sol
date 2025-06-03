// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.30;

import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";
import {LicredityChainlinkOracle} from "src/LicredityChainlinkOracle.sol";
import {Deployers} from "./Deployers.sol";

contract LicredityChainlinkOracleTest is Deployers {
    LicredityChainlinkOracle public oracle;

    function setUp() public {
        deployLicredity();
        deployMockChainlinkOracle();

        oracle = new LicredityChainlinkOracle(address(licredity), address(this));
    }

    modifier asLicredity() {
        vm.startPrank(address(licredity));
        _;
        vm.stopPrank();
    }

    function test_updateDebtTokenPrice_upperLimit() public asLicredity {
        skip(1);
        oracle.updateDebtTokenPrice(250541448375047946302209916928); // update price = 10
        assertApproxEqAbsDecimal(oracle.emaPrice(), 1015598980022670848, 1e4, 18);
    }

    function test_updateDebtTokenPrice_maxTime() public asLicredity {
        skip(6000);
        oracle.updateDebtTokenPrice(79843750678802117044226490368); // update price = 1.0156
        assertApproxEqAbsDecimal(oracle.emaPrice(), 1000000708238904192, 1e4, 18);
    }

    function test_updateDebtTokenPrice_normal() public asLicredity {
        skip(42);
        oracle.updateDebtTokenPrice(79346915759800263220867891200); // update price = 1.003
        assertApproxEqAbsDecimal(oracle.emaPrice(), 1002797181459717632, 1e4, 18);
    }

    function test_peekDebtToken(uint256 amount) public view {
        assertEq(oracle.peek(address(licredity), amount), amount);
    }

    function test_peekEthUsd() public {
        oracle.updateFeedsConfig(address(usd), AggregatorV3Interface(address(0)), ethUSD);

        uint256 peekAmount = oracle.peek(address(usd), 262341076816);
        assertEq(peekAmount, 1 ether);
    }

    function test_peekBtcEth() public {
        oracle.updateFeedsConfig(address(btc), btcETH, AggregatorV3Interface(address(0)));

        uint256 peekAmount = oracle.peek(address(btc), 1e8);
        assertEq(peekAmount, 40446685000000000000);
    }
}
