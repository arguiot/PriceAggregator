// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/PriceAggregator.sol";
import "../src/MockUniswapV3Pool.sol";

contract PriceAggregatorTest is Test {
    PriceAggregator aggregator;
    MockUniswapV3Pool mockPool;

    // SetUp is executed before every test.
    function setUp() public {
        aggregator = new PriceAggregator();
        mockPool = new MockUniswapV3Pool();
    }

    /// Test that a new pair is correctly registered and updated with TWAP data.
    function testNewPair() public {
        // Set observations such that:
        // tickCumulative0 = 0 and tickCumulative1 = 86400.
        // This yields an average tick = (86400 - 0) / 86400 = 1.
        mockPool.setObservations(0, 86400);

        // Register and update the "ETH/USD" pair.
        aggregator.updatePrice("ETH/USD", address(mockPool));

        (
            bytes32 chainHash,
            uint256 lastUpdateTimestamp,
            int256 lastPrice,
            uint256 lastUpdatedAt,
            uint256 lastBlockNumber
        ) = aggregator.getPriceInfo("ETH/USD");

        // Check that the chain hash is not empty.
        assertTrue(chainHash != bytes32(0), "ChainHash should not be 0");
        // lastPrice (average tick) should be 1.
        assertEq(lastPrice, 1, "Expected average tick to be 1");
        // lastUpdateTimestamp and lastUpdatedAt should be equal and nonzero.
        assertGt(lastUpdateTimestamp, 0, "Timestamp should be > 0");
        assertEq(lastUpdatedAt, lastUpdateTimestamp, "Timestamps should match");
        // lastBlockNumber should equal the current block.
        assertEq(lastBlockNumber, block.number, "Block numbers should match");
    }

    /// Test that updating an existing pair works after the update interval has passed.
    function testExistingPairUpdate() public {
        // For the pair "BTC/USD", first set mock observations to return an average tick of 2.
        // e.g., tickCumulative0 = 0, tickCumulative1 = TWAP_PERIOD * 2 = 86400 * 2.
        mockPool.setObservations(0, 86400 * 2);
        aggregator.updatePrice("BTC/USD", address(mockPool));

        // Save the initial chain hash and timestamp.
        (bytes32 initialHash, uint256 initialTimestamp, int256 initialPrice,,) = aggregator.getPriceInfo("BTC/USD");
        assertEq(initialPrice, 2, "Expected average tick of 2");

        // Advance time by just over one day.
        vm.warp(block.timestamp + 1 days + 1);

        // Update the mock to simulate a new TWAP result: average tick = 3
        // Set tickCumulative0 = 0, tickCumulative1 = TWAP_PERIOD * 3.
        mockPool.setObservations(0, 86400 * 3);

        // For an existing pair, we can pass address(0) to use the already stored pool.
        aggregator.updatePrice("BTC/USD", address(0));

        (bytes32 newHash, uint256 newTimestamp, int256 newPrice, uint256 newUpdatedAt, uint256 newBlockNumber) =
            aggregator.getPriceInfo("BTC/USD");

        // Validate that the chain hash has been updated.
        assertTrue(newHash != initialHash, "Chain hash should update");
        // Validate the new average tick is 3.
        assertEq(newPrice, 3, "Expected average tick of 3");
        // Ensure the timestamp has increased.
        assertGt(newTimestamp, initialTimestamp, "Timestamp should increase");
        // Block number should reflect the warp.
        assertEq(newBlockNumber, block.number, "Block number should match");
    }

    /// Test that updating too soon reverts.
    function testUpdateTooSoonReverts() public {
        mockPool.setObservations(0, 86400);
        aggregator.updatePrice("ETHUSD", address(mockPool));
        // Expect revert on a second update without waiting one day.
        vm.expectRevert("Update too soon");
        aggregator.updatePrice("ETHUSD", address(0));
    }

    /// Test that providing a mismatched pool address for an existing pair reverts.
    function testPoolAddressMismatchReverts() public {
        mockPool.setObservations(0, 86400);
        aggregator.updatePrice("LINK/USD", address(mockPool));
        // Provide a fake pool address.
        address fakePool = address(0x1234);
        vm.expectRevert("Pool address mismatch");
        aggregator.updatePrice("LINK/USD", fakePool);
    }
}
