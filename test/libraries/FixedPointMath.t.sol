// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";
import {PipsMath} from "@licredity-v1-core/libraries/PipsMath.sol";
import {FixedPointMath} from "src/libraries/FixedPointMath.sol";

contract FixedPointMathTest is Test {
    /// @dev Returns `exp(x)`, denominated in `WAD`.
    /// Credit to Remco Bloemen under MIT license: https://2π.com/22/exp-ln
    /// Note: This function is an approximation. Monotonically increasing.
    function expWad(int256 x) public pure returns (int256 r) {
        unchecked {
            // When the result is less than 0.5 we return zero.
            // This happens when `x <= (log(2 ** -96) * 2 ** 96`.
            if (x <= -5272010636899916983850139385856) return r;

            /// @solidity memory-safe-assembly
            assembly {
                // When the result is greater than `(2**255 - 1) / 1e18` we can not represent it as
                // an int. This happens when `x >= floor(log((2**255 - 1) / 1e18) * 1e18) ≈ 135`.
                if iszero(slt(x, 135305999368893231589)) {
                    mstore(0x00, 0xa37bfec9) // `ExpOverflow()`.
                    revert(0x1c, 0x04)
                }
            }

            // `x` is now in the range `(-42, 136) * 1e18`. Convert to `(-42, 136) * 2**96`
            // for more intermediate precision and a binary basis. This base conversion
            // is a multiplication by 1e18 / 2**96 = 5**18 / 2**78.
            x = (x << 78) / 5 ** 18;

            // Reduce range of x to (-½ ln 2, ½ ln 2) * 2**96 by factoring out powers
            // of two such that exp(x) = exp(x') * 2**k, where k is an integer.
            // Solving this gives k = round(x / log(2)) and x' = x - k * log(2).
            int256 k = ((x << 96) / 54916777467707473351141471128 + 2 ** 95) >> 96;
            x = x - k * 54916777467707473351141471128;

            // `k` is in the range `[-61, 195]`.

            // Evaluate using a (6, 7)-term rational approximation.
            // `p` is made monic, we'll multiply by a scale factor later.
            int256 y = x + 1346386616545796478920950773328;
            y = ((y * x) >> 96) + 57155421227552351082224309758442;
            int256 p = y + x - 94201549194550492254356042504812;
            p = ((p * y) >> 96) + 28719021644029726153956944680412240;
            p = p * x + (4385272521454847904659076985693276 << 96);

            // We leave `p` in `2**192` basis so we don't need to scale it back up for the division.
            int256 q = x - 2855989394907223263936484059900;
            q = ((q * x) >> 96) + 50020603652535783019961831881945;
            q = ((q * x) >> 96) - 533845033583426703283633433725380;
            q = ((q * x) >> 96) + 3604857256930695427073651918091429;
            q = ((q * x) >> 96) - 14423608567350463180887372962807573;
            q = ((q * x) >> 96) + 26449188498355588339934803723976023;

            /// @solidity memory-safe-assembly
            assembly {
                // Div in assembly because solidity adds a zero check despite the unchecked.
                // The q polynomial won't have zeros in the domain as all its roots are complex.
                // No scaling is necessary because p is already `2**96` too large.
                r := sdiv(p, q)
            }

            // r should be in the range `(0.09, 0.25) * 2**96`.

            // We now need to multiply r by:
            // - The scale factor `s ≈ 6.031367120`.
            // - The `2**k` factor from the range reduction.
            // - The `1e18 / 2**96` factor for base conversion.
            // We do this all at once, with an intermediate result in `2**213`
            // basis, so the final right shift is always by a positive amount.
            r = int256((uint256(r) * 3822833074963236453042738258902158003155416615667) >> uint256(195 - k));
        }
    }

    function expWadX96(int256 x) public pure returns (int256 r) {
        return FixedPointMath.expWadX96(x);
    }

    function test_expWad_zero() public pure {
        assertEq(expWad(0), 1 ether);
        assertEq(FixedPointMath.expWadX96(0), 1 << 96);
    }

    function test_expWadX96(int256 xWad) public view {
        vm.assume(xWad < 0);
        vm.assume(xWad > -1461501637330902918203684832716283019655932542976);

        int256 x96 = (xWad << 78) / 5 ** 18;

        (bool success0, bytes memory result0) =
            address(this).staticcall(abi.encodeWithSignature("expWadX96(int256)", x96));
        (bool success1, bytes memory result1) =
            address(this).staticcall(abi.encodeWithSignature("expWad(int256)", xWad));

        assertEq(success0, success1);
        if (success0) {
            int256 expWadX96Res = abi.decode(result0, (int256));
            int256 wadRes = (expWadX96Res * 1e18) >> 96;

            assertApproxEqRel(wadRes, abi.decode(result1, (int256)), 0.01 ether);
        }
    }

    /// @dev Returns `ceil(x * y / d)`.
    /// Reverts if `x * y` overflows, or `d` is zero.
    function mulDivUp(uint256 x, uint256 y, uint256 d) public pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            // Equivalent to `require(d != 0 && (y == 0 || x <= type(uint256).max / y))`.
            if iszero(mul(or(iszero(x), eq(div(z, x), y)), d)) {
                mstore(0x00, 0xad251c27) // `MulDivFailed()`.
                revert(0x1c, 0x04)
            }
            z := add(iszero(iszero(mod(z, d))), div(z, d))
        }
    }

    function mulPipsUp(uint256 x, uint24 y) public pure returns (uint256 z) {
        return PipsMath.pipsMulUp(x, y);
    }

    function test_mulPipsUp(uint256 x, uint256 y) public view {
        (bool success0, bytes memory result0) =
            address(this).staticcall(abi.encodeWithSignature("mulDivUp(uint256, uint256, uint256)", x, y, 1_000_000));
        (bool success1, bytes memory result1) =
            address(this).staticcall(abi.encodeWithSignature("mulPipsUp(uint256, uint256)", x, y));

        assertEq(success0, success1);
        if (success0) {
            assertEq(abi.decode(result0, (uint256)), abi.decode(result1, (uint256)));
        }
    }
}
