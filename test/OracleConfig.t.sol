// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@forge-std/interfaces/IERC20.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {PoolId} from "@uniswap-v4-core/types/PoolId.sol";
import {AggregatorV3Interface} from "src/interfaces/external/AggregatorV3Interface.sol";
import {IChainlinkOracle} from "src/interfaces/IChainlinkOracle.sol";
import {IChainlinkOracleConfigs} from "src/interfaces/IChainlinkOracleConfigs.sol";
import {IPositionManager} from "src/modules/uniswap/v4/interfaces/IPositionManager.sol";
import {ChainlinkOracle} from "src/ChainlinkOracle.sol";
import {FixedPointMath} from "src/libraries/FixedPointMath.sol";
import {Deployers} from "./utils/Deployers.sol";

contract LicredityChainlinkOracleManageTest is Deployers {
    error NotGovernor();
    error NotExistFungibleFeedConfig();
    error AlreadyInitialized();
    error InvalidMrrPips();

    ChainlinkOracle public oracle;
    PoolId public mockPoolId;
    address public licredityFungible;

    function setUp() public {
        deployLicredity();
        deployUniswapV4MockPool();
        deployMockChainlinkOracle();

        mockPoolId = PoolId.wrap(bytes32(hex"01"));
        licredity.setPoolManagerAndPoolId(address(uniswapV4Mock), mockPoolId);
        uniswapV4Mock.setPoolIdSqrtPriceX96(mockPoolId, 1 << 96);

        oracle = new ChainlinkOracle(address(licredity), address(this));

        licredityFungible = address(licredity);
    }

    function test_updateGovernor() public {
        vm.expectEmit(true, false, false, false);
        emit IChainlinkOracleConfigs.UpdateGovernor(address(1));
        oracle.updateGovernor(address(1));
    }

    function test_updateGovernor_notGovernor() public {
        vm.startPrank(address(1));
        vm.expectRevert(NotGovernor.selector);
        oracle.updateGovernor(address(1));
        vm.stopPrank();
    }

    function test_updateFungibleFeedsConfig(
        uint8 decimals,
        uint24 mrrPips,
        uint8 baseFeedDecimals,
        uint8 quoteFeedDecimals
    ) public {
        decimals = uint8(bound(decimals, 0, 36));
        baseFeedDecimals = uint8(bound(baseFeedDecimals, 0, 36));
        quoteFeedDecimals = uint8(bound(quoteFeedDecimals, 0, 36));
        vm.assume(18 + uint256(quoteFeedDecimals) + uint256(18) > (uint256(baseFeedDecimals) + uint256(decimals)));

        Fungible asset = Fungible.wrap(vm.addr(1));
        AggregatorV3Interface baseFeed = AggregatorV3Interface(vm.addr(2));
        AggregatorV3Interface quoteFeed = AggregatorV3Interface(vm.addr(3));

        vm.mockCall(
            address(baseFeed),
            abi.encodeWithSelector(AggregatorV3Interface.decimals.selector),
            abi.encode(baseFeedDecimals)
        );

        vm.mockCall(
            address(quoteFeed),
            abi.encodeWithSelector(AggregatorV3Interface.decimals.selector),
            abi.encode(quoteFeedDecimals)
        );

        vm.mockCall(Fungible.unwrap(asset), abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));
        if (mrrPips > FixedPointMath.UNIT_PIPS) {
            vm.expectRevert(InvalidMrrPips.selector);
        } else {
            vm.expectEmit(true, false, false, false);
            emit IChainlinkOracleConfigs.SetFungibleConfig(asset, mrrPips, 0, baseFeed, quoteFeed);
        }

        oracle.setFungibleConfig(asset, mrrPips, baseFeed, quoteFeed);
    }

    function test_deleteFungibleFeedsConfig(uint256 seed) public {
        Fungible asset = Fungible.wrap(address(uint160(bound(seed, 1000, 1000_000_000))));
        vm.mockCall(Fungible.unwrap(asset), abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(uint8(8)));
        oracle.setFungibleConfig(asset, 10, AggregatorV3Interface(address(0)), AggregatorV3Interface(address(0)));

        vm.expectEmit(true, false, false, false);
        emit IChainlinkOracleConfigs.DeleteFungibleConfig(asset);
        oracle.deleteFungibleConfig(asset);
    }

    function test_UniswapV4ModuleInit() public {
        oracle.initializeUniswapV4Module(
            address(0x000000000004444c5dc75cB358380D2e3dE08A90), address(0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e)
        );
    }

    function test_UniswapV4ModuleInit_initalized() public {
        oracle.initializeUniswapV4Module(
            address(0x000000000004444c5dc75cB358380D2e3dE08A90), address(0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e)
        );

        vm.expectRevert(AlreadyInitialized.selector);
        oracle.initializeUniswapV4Module(
            address(0x000000000004444c5dc75cB358380D2e3dE08A90), address(0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e)
        );
    }

    function test_UniswapV4Module_update(PoolId poolId) public {
        vm.expectEmit(true, false, false, true);
        emit IChainlinkOracleConfigs.SetUniswapV4Pool(poolId, true);
        oracle.setUniswapV4Pool(poolId, true);

        vm.expectEmit(true, false, false, true);
        emit IChainlinkOracleConfigs.SetUniswapV4Pool(poolId, false);
        oracle.setUniswapV4Pool(poolId, false);
    }

    function test_UniswapV3ModuleInit_initalized() public {
        oracle.initializeUniswapV3Module(
            address(0x1F98431c8aD98523631AE4a59f267346ea31F984), address(0xC36442b4a4522E871399CD717aBDD847Ab11FE88)
        );
        vm.expectRevert(AlreadyInitialized.selector);
        oracle.initializeUniswapV3Module(
            address(0x1F98431c8aD98523631AE4a59f267346ea31F984), address(0xC36442b4a4522E871399CD717aBDD847Ab11FE88)
        );
    }

    function test_UniswapV3Module_update(address pool) public {
        vm.expectEmit(true, false, false, true);
        emit IChainlinkOracleConfigs.SetUniswapV3Pool(pool, true);
        oracle.setUniswapV3Pool(pool, true);
    }
}
