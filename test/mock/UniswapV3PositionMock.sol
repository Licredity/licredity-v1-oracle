// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {INonfungiblePositionManager} from "src/modules/uniswap/v3/interfaces/INonfungiblePositionManager.sol";

struct PositionDataMock {
    uint96 nonce;
    address operator;
    address token0;
    address token1;
    uint24 fee;
    int24 tickLower;
    int24 tickUpper;
    uint128 liquidity;
    uint256 feeGrowthInside0LastX128;
    uint256 feeGrowthInside1LastX128;
    uint128 tokensOwed0;
    uint128 tokensOwed1;
}

contract UniswapV3NonfungiblePositionManagerMock is INonfungiblePositionManager {
    PositionDataMock internal positionData;
    address public factory;

    function setReturnData(PositionDataMock memory _positionData) external {
        positionData = _positionData;
    }

    function setFactory(address factory_) external {
        factory = factory_;
    }

    function positions(uint256)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        return (
            positionData.nonce,
            positionData.operator,
            positionData.token0,
            positionData.token1,
            positionData.fee,
            positionData.tickLower,
            positionData.tickUpper,
            positionData.liquidity,
            positionData.feeGrowthInside0LastX128,
            positionData.feeGrowthInside1LastX128,
            positionData.tokensOwed0,
            positionData.tokensOwed1
        );
    }
}
