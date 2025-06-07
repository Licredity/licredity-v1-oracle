// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {LicredityChainlinkOracle} from "src/LicredityChainlinkOracle.sol";
import {Fungible} from "src/types/Fungible.sol";
import {NonFungible} from "src/types/NonFungible.sol";
import {Deployers} from "./Deployers.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IPositionManager} from "src/interfaces/IPositionManager.sol";
import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";

contract NonFungibleOracleTest is Deployers {
    LicredityChainlinkOracle public oracle;
    PoolId public ETHUSDCPoolId;
    AggregatorV3Interface public constant ZERO_ORACLE = AggregatorV3Interface(address(0));
    address public constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    function setUp() public {
        deployLicredity();

        vm.createSelectFork("ETH", 22638094);

        ETHUSDCPoolId = PoolId.wrap(bytes32(0x21c67e77068de97969ba93d4aab21826d33ca12bb9f565d8496e8fda8a82ca27));
        oracle = new LicredityChainlinkOracle(
            address(licredity),
            address(this),
            ETHUSDCPoolId,
            IPoolManager(address(0x000000000004444c5dc75cB358380D2e3dE08A90)),
            IPositionManager(address(0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e))
        );
    }

    function getFungible(uint256 tokenId) public pure returns (NonFungible nft) {
        assembly ("memory-safe") {
            nft := or(0xbd216513d74c8cf14cf4747e6aaa6420ff64ee9e000000000000000000000000, tokenId)
        }
    }

    function test_quoteNonFungible_ETHUSDC() public {
        oracle.updateNonFungiblePoolIdWhitelist(ETHUSDCPoolId);
        
        NonFungible nft = getFungible(23864);
        oracle.updateFungibleFeedsConfig(Fungible.wrap(address(0)), ZERO_ORACLE, ZERO_ORACLE);
        oracle.updateFungibleFeedsConfig(
            Fungible.wrap(USDC),
            ZERO_ORACLE,
            AggregatorV3Interface(address(0x5147eA642CAEF7BD9c1265AadcA78f997AbB9649))
        );
        // ETH / USDC = 2602.68440965, ETH / pegETH = 0.984375
        uint256 debtTokenAmount = oracle.quoteNonFungible(nft);
        // assertEq(debtTokenAmount, 4903006588562427069110 + 3368008528943);
        assertApproxEqAbsDecimal(debtTokenAmount, 4826397110616138448896 + 1294051832199103643648, 1e6, 18);
    }
}
