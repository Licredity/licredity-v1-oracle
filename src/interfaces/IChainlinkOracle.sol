// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IOracle} from "@licredity-v1-core/interfaces/IOracle.sol";
import {IChainlinkOracleConfigs} from "./IChainlinkOracleConfigs.sol";

interface IChainlinkOracle is IOracle, IChainlinkOracleConfigs {}
