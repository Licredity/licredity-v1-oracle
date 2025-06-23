// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Deployers} from "./Deployers.sol";
import {LicredityChainlinkOracle} from "src/LicredityChainlinkOracle.sol";
import {Fungible} from "src/types/Fungible.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IPositionManager} from "src/interfaces/IPositionManager.sol";
import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";
import {ILicredityChainlinkOracle} from "src/interfaces/ILicredityChainlinkOracle.sol";
import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract LicredityChainlinkOracleManageTest is Deployers {
    error NotOwner();

    LicredityChainlinkOracle public oracle;
    PoolId public mockPoolId;
    address public licredityFungible;

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

    function test_updateOwner() public {
        oracle.updateOwner(address(1));
        assertEq(oracle.owner(), address(1));
    }

    function test_updateOwner_notOwner() public {
        vm.startPrank(address(1));
        vm.expectRevert(NotOwner.selector);
        oracle.updateOwner(address(1));
        vm.stopPrank();
    }

    function test_updateFungibleFeedsConfig(
        Fungible asset,
        uint8 decimals,
        uint24 mrrPips,
        AggregatorV3Interface baseFeed,
        uint8 baseFeedDecimals,
        AggregatorV3Interface quoteFeed,
        uint8 quoteFeedDecimals
    ) public {
        decimals = uint8(bound(decimals, 0, 36));
        baseFeedDecimals = uint8(bound(baseFeedDecimals, 0, 36));
        quoteFeedDecimals = uint8(bound(quoteFeedDecimals, 0, 36));
        vm.assume(18 + uint256(quoteFeedDecimals) + uint256(18) > (uint256(baseFeedDecimals) + uint256(decimals)));
        vm.assume(address(baseFeed) != address(VM_ADDRESS));
        vm.assume(address(baseFeed) != address(VM_ADDRESS));
        if (address(baseFeed) != address(0)) {
            vm.mockCall(
                address(baseFeed),
                abi.encodeWithSelector(AggregatorV3Interface.decimals.selector),
                abi.encode(baseFeedDecimals)
            );
        }

        if (address(quoteFeed) != address(0)) {
            vm.mockCall(
                address(quoteFeed),
                abi.encodeWithSelector(AggregatorV3Interface.decimals.selector),
                abi.encode(quoteFeedDecimals)
            );
        }

        vm.mockCall(Fungible.unwrap(asset), abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));
        vm.expectEmit(true, false, false, true);
        emit ILicredityChainlinkOracle.FeedsUpdated(asset, mrrPips, baseFeed, quoteFeed);
        oracle.updateFungibleFeedsConfig(asset, mrrPips, baseFeed, quoteFeed);
    }

    function test_deleteFungibleFeedsConfig(Fungible asset) public {
        vm.expectEmit(true, false, false, false);
        emit ILicredityChainlinkOracle.FeedsDeleted(asset);
        oracle.deleteFungibleFeedsConfig(asset);
    }

    function test_updateNonFungiblePoolIdWhitelist(PoolId id) public {
        vm.expectEmit(true, false, false, false);
        emit ILicredityChainlinkOracle.PoolIdWhitelistUpdated(id, true);
        oracle.updateNonFungiblePoolIdWhitelist(id);
    }

    function test_deleteNonFungiblePoolIdWhitelist(PoolId id) public {
        vm.expectEmit(true, false, false, false);
        emit ILicredityChainlinkOracle.PoolIdWhitelistUpdated(id, false);
        oracle.deleteNonFungiblePoolIdWhitelist(id);
    }
}
