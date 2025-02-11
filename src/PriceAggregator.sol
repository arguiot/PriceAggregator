// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title PriceAggregator
 * @notice This contract aggregates prices using a Uniswap V3 pool's TWAP.
 * Anyone can register/update a trading pair (identified by a string).
 * - For a new pair, the provided Uniswap V3 pool address is recorded.
 * - For an existing pair, if a nonzero pool address is provided, it must match the registered one.
 * Updates are only allowed if at least one day has passed since the last update.
 *
 * Each update:
 *  - Calls the pool’s observe() method with [TWAP_PERIOD, 0].
 *  - Computes the average tick: (tickCumulative[1] - tickCumulative[0]) / TWAP_PERIOD.
 *  - Updates a chain hash to provide an auditable record of price updates.
 *  - Records the computed average tick as lastPrice along with the update time and block number.
 */
interface IUniswapV3Pool {
    /**
     * @notice Returns cumulative tick values and liquidity observations as of each timestamp in secondsAgos.
     * @param secondsAgos An array of time intervals in seconds ago from the current block timestamp.
     * @return tickCumulatives An array with the cumulative tick values.
     * @return secondsPerLiquidityCumulativeX128s An array with liquidity data (unused in this example).
     */
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);
}

contract PriceAggregator {
    // TWAP period for computing the average tick (set to 1 day, 86,400 seconds)
    uint32 public constant TWAP_PERIOD = 86400;
    // Update interval (1 day)
    uint256 public constant UPDATE_INTERVAL = 1 days;

    // Struct to hold price update information.
    struct PriceInfo {
        bytes32 chainHash; // Running hash chaining together all updates.
        uint256 lastUpdateTimestamp; // Timestamp when updatePrice was last executed.
        int256 lastPrice; // Computed average tick from the pool's TWAP observation.
        uint256 lastUpdatedAt; // Timestamp (set to block.timestamp here).
        uint256 lastBlockNumber; // Block number when updatePrice was called.
    }

    // Mapping from trading pair (e.g., "ETH/USD") to PriceInfo.
    mapping(string => PriceInfo) public priceInfo;
    // Mapping from trading pair to the associated Uniswap V3 pool.
    mapping(string => IUniswapV3Pool) public pools;

    // Event emitted when a price update occurs.
    event PriceUpdated(
        string indexed pair, int256 averageTick, uint256 updatedAt, uint256 blockNumber, bytes32 newChainHash
    );

    /**
     * @notice Updates the price for a given trading pair using the Uniswap V3 pool's TWAP.
     * If the pair is new, the provided poolAddress is registered.
     * For an existing pair, if a nonzero poolAddress is provided, it must match the stored pool.
     * Updates are allowed only if at least one day has elapsed since the last update.
     *
     * @param pair The trading pair identifier (e.g., "ETH/USD").
     * @param poolAddress The Uniswap V3 pool address to be used for this pair.
     *        For an existing pair, pass address(0) or the correct pool address.
     */
    function updatePrice(string calldata pair, address poolAddress) external {
        require(bytes(pair).length > 0, "Invalid pair identifier");

        IUniswapV3Pool pool = pools[pair];

        // If the pair is not yet registered, register it.
        if (address(pool) == address(0)) {
            require(poolAddress != address(0), "Pool address required for new pair");
            pool = IUniswapV3Pool(poolAddress);
            pools[pair] = pool;
        } else {
            // For an existing pair, if a poolAddress is provided (nonzero), it must match.
            if (poolAddress != address(0)) {
                require(poolAddress == address(pool), "Pool address mismatch");
            }
        }

        PriceInfo storage info = priceInfo[pair];
        // Enforce update interval if already updated before.
        if (info.lastUpdateTimestamp > 0) {
            require(block.timestamp >= info.lastUpdateTimestamp + UPDATE_INTERVAL, "Update too soon");
        }

        // Prepare parameters for TWAP observation.
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = TWAP_PERIOD;
        secondsAgos[1] = 0;

        // Fetch TWAP-related data from the Uniswap V3 pool.
        (int56[] memory tickCumulatives,) = pool.observe(secondsAgos);
        // Compute average tick: (tickCumulatives[1] - tickCumulatives[0]) / TWAP_PERIOD.
        int56 tickCumulativeDelta = tickCumulatives[1] - tickCumulatives[0];
        int256 averageTick = int256(tickCumulativeDelta) / int256(uint256(TWAP_PERIOD));

        // Create a new chain hash by combining the previous hash with the new update data.
        bytes32 newChainHash = keccak256(abi.encodePacked(info.chainHash, averageTick, block.timestamp, block.number));

        // Update the price info.
        info.chainHash = newChainHash;
        info.lastPrice = averageTick;
        info.lastUpdatedAt = block.timestamp;
        info.lastUpdateTimestamp = block.timestamp;
        info.lastBlockNumber = block.number;

        emit PriceUpdated(pair, averageTick, block.timestamp, block.number, newChainHash);
    }

    /**
     * @notice Retrieve stored price information for a given trading pair.
     * @param pair The trading pair identifier.
     * @return chainHash Running chain hash of price updates.
     * @return lastUpdateTimestamp When the pair was last updated.
     * @return lastPrice The last computed average tick.
     * @return lastUpdatedAt The timestamp set during the last update.
     * @return lastBlockNumber The block number when updatePrice was last called.
     */
    function getPriceInfo(string calldata pair)
        external
        view
        returns (
            bytes32 chainHash,
            uint256 lastUpdateTimestamp,
            int256 lastPrice,
            uint256 lastUpdatedAt,
            uint256 lastBlockNumber
        )
    {
        require(address(pools[pair]) != address(0), "Pair not tracked");
        PriceInfo memory info = priceInfo[pair];
        return (info.chainHash, info.lastUpdateTimestamp, info.lastPrice, info.lastUpdatedAt, info.lastBlockNumber);
    }
}
