// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Deployers} from "./Deployers.sol";
import {LicredityChainlinkOracle} from "src/LicredityChainlinkOracle.sol";
import {Fungible} from "src/types/Fungible.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUniswapV4PositionManager} from "src/interfaces/external/IUniswapV4PositionManager.sol";
import {AggregatorV3Interface} from "src/interfaces/external/AggregatorV3Interface.sol";
import {IPositionConfig} from "src/interfaces/IPositionConfig.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract LicredityChainlinkOracleManageTest is Deployers {
    error NotGovernor();
    error NotExistFungibleFeedConfig();
    error AlreadyInitialized();

    LicredityChainlinkOracle public oracle;
    PoolId public mockPoolId;
    address public licredityFungible;

    function setUp() public {
        deployLicredity();
        deployUniswapV4MockPool();
        deployMockChainlinkOracle();

        mockPoolId = PoolId.wrap(bytes32(hex"01"));
        oracle = new LicredityChainlinkOracle(address(licredity), address(this), mockPoolId, IPoolManager(address(0)));

        licredityFungible = address(licredity);
    }

    function test_updateGovernor() public {
        vm.expectEmit(true, false, false, false);
        emit IPositionConfig.UpdateGovernor(address(1));
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
        vm.expectEmit(true, false, false, true);
        emit IPositionConfig.FeedsUpdate(asset, mrrPips, baseFeed, quoteFeed);
        oracle.updateFungibleFeedsConfig(asset, mrrPips, baseFeed, quoteFeed);
    }

    function test_deleteFungibleFeedsConfig_NotExist(Fungible asset) public {
        vm.expectRevert(NotExistFungibleFeedConfig.selector);
        oracle.deleteFungibleFeedsConfig(asset);
    }

    function test_deleteFungibleFeedsConfig(Fungible asset) public {
        vm.assume(Fungible.unwrap(asset) != address(VM_ADDRESS));

        vm.mockCall(Fungible.unwrap(asset), abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(uint8(8)));
        oracle.updateFungibleFeedsConfig(
            asset, 10, AggregatorV3Interface(address(0)), AggregatorV3Interface(address(0))
        );

        vm.expectEmit(true, false, false, false);
        emit IPositionConfig.FeedsDelete(asset);
        oracle.deleteFungibleFeedsConfig(asset);
    }

    function test_UniswapV4ModuleInit() public {
        oracle.initUniswapV4PositionModule(
            IPoolManager(address(0x000000000004444c5dc75cB358380D2e3dE08A90)),
            IUniswapV4PositionManager(address(0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e))
        );
    }

    function test_UniswapV4ModuleInit_initalized() public {
        oracle.initUniswapV4PositionModule(
            IPoolManager(address(0x000000000004444c5dc75cB358380D2e3dE08A90)),
            IUniswapV4PositionManager(address(0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e))
        );

        vm.expectRevert(AlreadyInitialized.selector);
        oracle.initUniswapV4PositionModule(
            IPoolManager(address(0x000000000004444c5dc75cB358380D2e3dE08A90)),
            IUniswapV4PositionManager(address(0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e))
        );
    }

    function test_UniswapV4Module_update(PoolId poolId) public {
        vm.expectEmit(true, false, false, true);
        emit IPositionConfig.UniswapV4WhitelistUpdated(poolId, true);
        oracle.setUniswapV4Whitelist(poolId, true);

        vm.expectEmit(true, false, false, true);
        emit IPositionConfig.UniswapV4WhitelistUpdated(poolId, false);
        oracle.setUniswapV4Whitelist(poolId, false);
    }
}
