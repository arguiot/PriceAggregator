// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./PriceAggregator.sol";

/**
 * @title MockUniswapV3Pool
 * @notice This mock simulates a Uniswap V3 pool's observe() function.
 * It allows tests to set arbitrary tickCumulative values.
 *
 * When observe() is called, it returns fixed tick cumulative values specified by the test.
 */
contract MockUniswapV3Pool is IUniswapV3Pool {
    int56 public tickCumulative0;
    int56 public tickCumulative1;

    /**
     * @notice Set the tick cumulative values to be returned by observe().
     * @param _tickCumulative0 The tick cumulative value for secondsAgo = TWAP_PERIOD.
     * @param _tickCumulative1 The tick cumulative value for secondsAgo = 0.
     */
    function setObservations(int56 _tickCumulative0, int56 _tickCumulative1) external {
        tickCumulative0 = _tickCumulative0;
        tickCumulative1 = _tickCumulative1;
    }

    /**
     * @notice Returns the stored tick cumulative values.
     * @param secondsAgos An array of seconds ago. This mock ignores the actual values and returns preset observations.
     * @return tickCumulatives An array with two tick cumulative values.
     * @return secondsPerLiquidityCumulativeX128s An empty array (unused in this mock).
     */
    function observe(uint32[] calldata secondsAgos)
        external
        view
        override
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        // We ignore the input parameter as this is a mock.
        tickCumulatives = new int56[](2);
        tickCumulatives[0] = tickCumulative0;
        tickCumulatives[1] = tickCumulative1;

        // Return an empty array for secondsPerLiquidityCumulativeX128s.
        secondsPerLiquidityCumulativeX128s = new uint160[](2);
    }
}
