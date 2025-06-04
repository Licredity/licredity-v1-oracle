// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ChainlinkOracleMock} from "./mock/ChainlinkOracleMock.sol";
import {UniswapV4PoolMock} from "./mock/UniswapV4PoolMock.sol";
import {DecimalsMock} from "./mock/DecimalsMock.sol";

contract Deployers is Test {
    DecimalsMock public licredity;
    DecimalsMock public usd;
    DecimalsMock public btc;

    ChainlinkOracleMock public ethUSD;
    ChainlinkOracleMock public btcETH;

    UniswapV4PoolMock public uniswapV4Mock;

    function deployLicredity() public {
        licredity = new DecimalsMock();
        licredity.setDecimals(18);
    }

    function deployUniswapV4Pool() public {
        uniswapV4Mock = new UniswapV4PoolMock();
    }

    function deployMockChainlinkOracle() public {
        ethUSD = new ChainlinkOracleMock(8, "EthUSD");
        usd = new DecimalsMock();
        usd.setDecimals(8);
        ethUSD.setAnswer(262341076816);

        btcETH = new ChainlinkOracleMock(18, "BtcETH");
        btc = new DecimalsMock();
        btc.setDecimals(8);
        btcETH.setAnswer(40446685000000000000);
    }
}
