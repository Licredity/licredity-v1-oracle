// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IOracle} from "./IOracle.sol";
import {IPositionConfig} from "./IPositionConfig.sol";

interface ILicredityChainlinkOracle is IOracle, IPositionConfig {}
