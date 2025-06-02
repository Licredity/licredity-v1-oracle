// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.30;

import {LicredityChainlinkOracle} from "src/LicredityChainlinkOracle.sol";
import {Test} from "forge-std/Test.sol";

contract LicredityChainlinkOracleTest is Test {
    LicredityChainlinkOracle public oracle;

    function setUp() public {
        oracle = new LicredityChainlinkOracle(address(this), address(this));
    }

    function test_updateDebtTokenPrice_upperLimit() public {
        skip(1);
        oracle.updateDebtTokenPrice(250541448375047946302209916928); // update price = 10
        assertApproxEqAbsDecimal(oracle.emaPrice(), 1015598980022670848, 1e4, 18);
    }

    function test_updateDebtTokenPrice_maxTime() public {
        skip(6000);
        oracle.updateDebtTokenPrice(79843750678802117044226490368); // update price = 1.0156
        assertApproxEqAbsDecimal(oracle.emaPrice(), 1000000708238904192, 1e4, 18);
    }

    function test_updateDebtTokenPrice_normal() public {
        skip(42);
        oracle.updateDebtTokenPrice(79346915759800263220867891200); // update price = 1.003
        assertApproxEqAbsDecimal(oracle.emaPrice(), 1002797181459717632, 1e4, 18);
    }
}
