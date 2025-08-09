// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "@forge-std/Script.sol";
import {console} from "@forge-std/console.sol";
import {ChainlinkOracle} from "../src/ChainlinkOracle.sol";

contract DeployOracleScript is Script {
    function run() external {
        // Load deployment settings
        string memory chain = vm.envString("CHAIN");
        console.log("Deploying to chain ", chain);

        // Load deployment parameters
        address licredity = vm.envAddress(string.concat(chain, "_LICREDITY_CORE"));
        address governor = vm.envAddress(string.concat(chain, "_GOVERNOR"));
        console.log("Governor:", governor);
        console.log("Licredity:", licredity);

        // Validate deployment parameters
        require(governor != address(0), "Governor address cannot be zero");
        require(licredity != address(0), "Licredity address cannot be zero");

        // Deploy contracts
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        ChainlinkOracle oracle = new ChainlinkOracle(licredity, governor);
        vm.stopBroadcast();
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("ChainlinkOracle deployed at:", address(oracle));

        // Save deployment
        string memory fileName = string.concat("./deployments/", chain, "_ChainlinkOracle.env");
        vm.writeFile(
            fileName,
            string.concat(
                "# Chainlink oracle on ",
                chain,
                " deployed at: ",
                vm.toString(address(oracle)),
                "\n",
                "Licredity: ",
                vm.toString(licredity),
                "\n",
                "Governor: ",
                vm.toString(governor),
                "\n"
            )
        );
        console.log("Deployment info saved to:", fileName);
    }
}
