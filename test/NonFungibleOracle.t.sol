// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {NonFungible} from "@licredity-v1-core/types/NonFungible.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {PoolId} from "@uniswap-v4-core/types/PoolId.sol";
import {AggregatorV3Interface} from "src/interfaces/external/AggregatorV3Interface.sol";
import {IPositionManager} from "src/modules/uniswap/v4/interfaces/IPositionManager.sol";
import {ChainlinkOracle} from "src/ChainlinkOracle.sol";
import {Deployers} from "./Deployers.sol";

contract NonFungibleOracleTest is Deployers {
    ChainlinkOracle public oracle;
    PoolId public ETHUSDCPoolId;
    AggregatorV3Interface public constant ZERO_ORACLE = AggregatorV3Interface(address(0));
    address public constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public position = address(0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e);

    function setUp() public {
        deployLicredity();
        deployUniswapV4MockPool();

        vm.createSelectFork("ETH", 22638094);

        IPoolManager v4Manager = IPoolManager(address(0x000000000004444c5dc75cB358380D2e3dE08A90));
        ETHUSDCPoolId = PoolId.wrap(bytes32(0x21c67e77068de97969ba93d4aab21826d33ca12bb9f565d8496e8fda8a82ca27));

        uniswapV4Mock.setPoolIdSqrtPriceX96(ETHUSDCPoolId, 1 << 96);
        licredity.setPoolManagerAndPoolId(address(uniswapV4Mock), ETHUSDCPoolId);

        oracle = new ChainlinkOracle(address(licredity), address(this));

        oracle.initializeUniswapV4Module(address(v4Manager), address(0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e));
    }

    function getFungible(uint256 tokenId) public pure returns (NonFungible nft) {
        assembly ("memory-safe") {
            nft := or(0xbd216513d74c8cf14cf4747e6aaa6420ff64ee9e000000000000000000000000, tokenId)
        }
    }

    function test_quoteNonFungible_notPositionManager() public {
        NonFungible nft;
        assembly ("memory-safe") {
            nft := or(0xcd216513d74c8cf14cf4747e6aaa6420ff64ee9e000000000000000000000000, 1)
        }

        NonFungible[] memory nonFungibles = new NonFungible[](1);
        nonFungibles[0] = nft;

        (uint256 value, uint256 marginRequirement) = oracle.quoteNonFungibles(nonFungibles);

        assertEq(value, 0);
        assertEq(marginRequirement, 0);
    }

    function test_quoteNonFungible_ETHUSDC_zero() public {
        NonFungible nft = getFungible(23864);
        NonFungible[] memory nonFungibles = new NonFungible[](1);
        nonFungibles[0] = nft;

        (uint256 value, uint256 marginRequirement) = oracle.quoteNonFungibles(nonFungibles);
        assertEq(value, 0);
        assertEq(marginRequirement, 0);
    }

    function test_quoteNonFungible_ETHUSDC() public {
        NonFungible nft = getFungible(23864);

        oracle.setUniswapV4Pool(ETHUSDCPoolId, true);

        NonFungible[] memory nonFungibles = new NonFungible[](1);
        nonFungibles[0] = nft;

        oracle.setFungibleConfig(Fungible.wrap(address(0)), 10, ZERO_ORACLE, ZERO_ORACLE);
        oracle.setFungibleConfig(
            Fungible.wrap(USDC),
            100,
            ZERO_ORACLE,
            AggregatorV3Interface(address(0x5147eA642CAEF7BD9c1265AadcA78f997AbB9649))
        );
        // ETH / USDC = 2602.68440965
        (uint256 debtTokenAmount,) = oracle.quoteNonFungibles(nonFungibles);
        // LP token = 4903006588562427069110 ETH + 3421468981784 USDC;
        assertApproxEqAbsDecimal(debtTokenAmount, 4903006588562427069110 + 1314592337472105218048, 1e5, 18);
    }
}
