// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/PriceAggregator.sol";
import "./MockAggregator.sol";

contract PriceAggregatorTest is Test {
    PriceAggregator aggregator;
    MockAggregator mock;

    // Set up the testing environment.
    function setUp() public {
        aggregator = new PriceAggregator();
        mock = new MockAggregator();

        // Initialize the mock aggregator to return a valid price.
        // We'll use:
        //   roundId: 1, price: 2000, startedAt: now, updatedAt: now, answeredInRound: 1.
        mock.setLatestRoundData(1, 2000, block.timestamp, block.timestamp, 1);
    }

    /// Test that a new pair is registered and updated.
    function testNewPair() public {
        // Call updatePrice with pair "ETH/USD" and register the mock as aggregator.
        aggregator.updatePrice("ETH/USD", address(mock));

        (
            bytes32 chainHash,
            uint256 lastUpdateTimestamp,
            int256 lastPrice,
            uint80 lastRoundId,
            uint256 lastUpdatedAt,
            uint256 lastBlockNumber
        ) = aggregator.getPriceInfo("ETH/USD");

        // Check that the price info is updated.
        assertTrue(chainHash != bytes32(0), "ChainHash should not be 0");
        assertEq(lastPrice, 2000, "Price should equal the value from mock");
        assertEq(lastRoundId, 1, "Round id should match");
        // lastUpdatedAt and block number can be further compared if necessary.
    }

    /// Test that a subsequent update for an existing pair works (after time warp).
    function testExistingPairUpdate() public {
        // First update for pair "BTC/USD".
        aggregator.updatePrice("BTC/USD", address(mock));

        // Save the first chain hash.
        (bytes32 initialHash, uint256 ts,,,,) = aggregator.getPriceInfo("BTC/USD");

        // Advance time by more than one day.
        vm.warp(block.timestamp + 1 days + 1);

        // Update the mock aggregator's data with new values.
        mock.setLatestRoundData(2, 2500, block.timestamp, block.timestamp, 2);

        // Update for the same pair. For an existing pair, pass address(0) or the correct aggregator.
        aggregator.updatePrice("BTC/USD", address(0));

        (
            bytes32 newChainHash,
            uint256 newTs,
            int256 newPrice,
            uint80 newRoundId,
            uint256 newUpdatedAt,
            uint256 newBlockNumber
        ) = aggregator.getPriceInfo("BTC/USD");

        // Verify that the chain hash has changed.
        assertTrue(newChainHash != initialHash, "New chain hash should differ from initial");

        // Validate new price data.
        assertEq(newPrice, 2500, "New price should equal the value from mock");
        assertEq(newRoundId, 2, "Round id should match updated value");

        // Ensure that the update timestamp has moved forward.
        assertGt(newTs, ts, "Timestamp should increase after update");
    }

    /// Test that updating too soon reverts.
    function testUpdateTooSoonReverts() public {
        // First update for pair "ETHUSD".
        aggregator.updatePrice("ETHUSD", address(mock));
        // Expect the second call to revert as we haven't waited a day.
        vm.expectRevert("Update too soon");
        aggregator.updatePrice("ETHUSD", address(0));
    }

    /// Test that providing a wrong aggregator for an existing pair reverts.
    function testAggregatorMismatchReverts() public {
        // First update registers pair "LINK/USD".
        aggregator.updatePrice("LINK/USD", address(mock));
        // Attempt to update with a nonzero aggregator address that is different.
        address fakeAggregator = address(0x1234);
        vm.expectRevert("Aggregator address mismatch");
        aggregator.updatePrice("LINK/USD", fakeAggregator);
    }
}
