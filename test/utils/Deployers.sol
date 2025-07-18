// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";
import {IHooks} from "@uniswap-v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {PoolSwapTest} from "@uniswap-v4-core/test/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "@uniswap-v4-core/test/PoolModifyLiquidityTest.sol";
import {TestERC20} from "@uniswap-v4-core/test/TestERC20.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";
import {PoolId} from "@uniswap-v4-core/types/PoolId.sol";
import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {ChainlinkOracleMock} from "../mock/ChainlinkOracleMock.sol";
import {DecimalsMock} from "../mock/DecimalsMock.sol";
import {LicredityMock} from "../mock/LicredityMock.sol";
import {UniswapV4PoolMock} from "../mock/UniswapV4PoolMock.sol";
import {TickMath} from "@uniswap-v4-core/libraries/TickMath.sol";

contract Deployers is Test {
    LicredityMock public licredity;
    DecimalsMock public usd;
    DecimalsMock public btc;

    ChainlinkOracleMock public ethUSD;
    ChainlinkOracleMock public btcETH;

    UniswapV4PoolMock public uniswapV4Mock;
    IPoolManager public v4PoolManager;
    PoolModifyLiquidityTest modifyLiquidityRouter;
    PoolSwapTest swapRouter;

    Currency internal currency0;
    Currency internal currency1;

    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_PRICE + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_PRICE - 1;

    function deployLicredity() public {
        licredity = new LicredityMock();
    }

    function deployUniswapV4MockPool() public {
        uniswapV4Mock = new UniswapV4PoolMock();
    }

    function deployMockChainlinkOracle() public {
        ethUSD = new ChainlinkOracleMock(8, "EthUSD");
        usd = new DecimalsMock();
        usd.setDecimals(8);
        ethUSD.setAnswer(262341076816);

        btcETH = new ChainlinkOracleMock(18, "BtcETH");
        btc = new DecimalsMock();
        btc.setDecimals(8);
        btcETH.setAnswer(40446685000000000000);
    }

    function deployFreshV4Manager(address initialOwner, bytes32 salt) internal {
        bytes memory args = abi.encode(initialOwner);
        bytes memory bytecode = vm.readFileBinary("test/bin/v4PoolManager.bytecode");
        bytes memory initcode = abi.encodePacked(bytecode, args);

        address v4PoolManagerAddr;
        assembly {
            v4PoolManagerAddr := create2(0, add(initcode, 0x20), mload(initcode), salt)
        }

        v4PoolManager = IPoolManager(v4PoolManagerAddr);
    }

    function deployFreshManagerAndRouters() internal {
        deployFreshV4Manager(address(this), bytes32(0));
        modifyLiquidityRouter = new PoolModifyLiquidityTest(v4PoolManager);
        swapRouter = new PoolSwapTest(v4PoolManager);

        vm.deal(address(modifyLiquidityRouter), 0);
    }

    function deployMintAndApprove2Currencies() internal {
        TestERC20 _currencyA = new TestERC20(2 ** 255);
        TestERC20 _currencyB = new TestERC20(2 ** 255);

        _currencyA.approve(address(modifyLiquidityRouter), type(uint256).max);
        _currencyB.approve(address(modifyLiquidityRouter), type(uint256).max);
        _currencyA.approve(address(swapRouter), type(uint256).max);
        _currencyB.approve(address(swapRouter), type(uint256).max);

        if (address(_currencyA) < address(_currencyB)) {
            currency0 = Currency.wrap(address(_currencyA));
            currency1 = Currency.wrap(address(_currencyB));
        } else {
            currency0 = Currency.wrap(address(_currencyB));
            currency1 = Currency.wrap(address(_currencyA));
        }
    }

    function initPool(
        Currency _currency0,
        Currency _currency1,
        IHooks hooks,
        uint24 fee,
        int24 tickSpacing,
        uint160 sqrtPriceX96
    ) internal returns (PoolKey memory _key, PoolId id) {
        _key = PoolKey(_currency0, _currency1, fee, tickSpacing, hooks);
        id = _key.toId();
        v4PoolManager.initialize(_key, sqrtPriceX96);
    }
}
