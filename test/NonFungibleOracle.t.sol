// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {LicredityChainlinkOracle} from "src/LicredityChainlinkOracle.sol";
import {NonFungible} from "src/types/NonFungible.sol";
import {Deployers} from "./Deployers.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IPositionManager} from "src/interfaces/IPositionManager.sol";

contract NonFungibleOracleTest is Deployers {
    LicredityChainlinkOracle public oracle;
    PoolId public ETHUSDCPoolId;

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
        NonFungible nft = getFungible(23864);
        // ETH / USDC = 0.984375
        uint256 debtTokenAmount = oracle.quoteNonFungible(nft);
        assertEq(debtTokenAmount, 4903006588562427069110 + 3368008528943);
    }
}
