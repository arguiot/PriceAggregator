// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @notice Minimal interface for a Chainlink Price Feed Aggregator.
interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/// @title PriceAggregator
/// @notice Anyone can add or update a trading pair.
///         • If the pair is new, the provided aggregator address is registered.
///         • For an existing pair, if an aggregator address is provided it must match the stored one.
///         • Anyone can call updatePrice once per day per pair.
///         • Each update fetches the Chainlink price and updates a chain hash including price, feed data, and block number.
contract PriceAggregator {
    // Interval for allowed updates (1 day).
    uint256 public constant UPDATE_INTERVAL = 1 days;

    // Struct to hold the price update information.
    struct PriceInfo {
        bytes32 chainHash; // Running hash of price updates.
        uint256 lastUpdateTimestamp; // Timestamp when updatePrice was last executed.
        int256 lastPrice; // Price fetched from the Chainlink Price Feed.
        uint80 lastRoundId; // Chainlink round id.
        uint256 lastUpdatedAt; // Timestamp reported by the Chainlink Price Feed.
        uint256 lastBlockNumber; // Block number when updatePrice was called.
    }

    // Mapping from trading pair identifier (e.g., "ETH/USD") to pricing information.
    mapping(string => PriceInfo) public priceInfo;
    // Mapping from trading pair identifier to the associated Chainlink Price Feed aggregator.
    mapping(string => AggregatorV3Interface) public priceFeeds;

    // Event emitted when a price update occurs.
    event PriceUpdated(
        string indexed pair,
        int256 price,
        uint80 roundId,
        uint256 feedUpdatedAt,
        uint256 blockNumber,
        bytes32 newChainHash
    );

    /**
     * @notice Updates the price for a given trading pair.
     *         If the pair is new, the provided aggregatorAddress is registered.
     *         If the pair is already tracked, then if a nonzero aggregatorAddress is provided,
     *         it must match the existing one.
     *         Anyone can call this function provided at least one day has passed since the last update.
     * @param pair The trading pair identifier (e.g., "ETH/USD").
     * @param aggregatorAddress The Chainlink Price Feed aggregator address.
     *        For existing pairs, pass address(0) or the correct aggregator address.
     */
    function updatePrice(string calldata pair, address aggregatorAddress) external {
        require(bytes(pair).length > 0, "Invalid pair identifier");

        AggregatorV3Interface feed = priceFeeds[pair];

        // If the pair is not yet registered, register it.
        if (address(feed) == address(0)) {
            require(aggregatorAddress != address(0), "Aggregator address required for new pair");
            feed = AggregatorV3Interface(aggregatorAddress);
            priceFeeds[pair] = feed;
        } else {
            // If an aggregator address is provided for an existing pair, enforce a match.
            if (aggregatorAddress != address(0)) {
                require(aggregatorAddress == address(feed), "Aggregator address mismatch");
            }
        }

        PriceInfo storage info = priceInfo[pair];
        // If the pair was updated before, enforce the update interval.
        if (info.lastUpdateTimestamp > 0) {
            require(block.timestamp >= info.lastUpdateTimestamp + UPDATE_INTERVAL, "Update too soon");
        }

        // Fetch the latest price data from the Chainlink Price Feed.
        (uint80 roundId, int256 price,, uint256 updatedAt,) = feed.latestRoundData();
        require(price > 0, "Invalid price");

        // Create a new chain hash by combining the previous hash with the new update data.
        bytes32 newChainHash = keccak256(abi.encodePacked(info.chainHash, price, updatedAt, roundId, block.number));

        // Update the price info.
        info.chainHash = newChainHash;
        info.lastPrice = price;
        info.lastRoundId = roundId;
        info.lastUpdatedAt = updatedAt;
        info.lastUpdateTimestamp = block.timestamp;
        info.lastBlockNumber = block.number;

        emit PriceUpdated(pair, price, roundId, updatedAt, block.number, newChainHash);
    }

    /**
     * @notice Retrieve all stored information for a given trading pair.
     * @param pair The trading pair identifier.
     * @return chainHash Running hash of all price updates.
     * @return lastUpdateTimestamp Timestamp when the pair was last updated.
     * @return lastPrice The latest fetched price.
     * @return lastRoundId The latest Chainlink round id.
     * @return lastUpdatedAt Timestamp received from the Chainlink Price Feed.
     * @return lastBlockNumber Block number when updatePrice was last called.
     */
    function getPriceInfo(string calldata pair)
        external
        view
        returns (
            bytes32 chainHash,
            uint256 lastUpdateTimestamp,
            int256 lastPrice,
            uint80 lastRoundId,
            uint256 lastUpdatedAt,
            uint256 lastBlockNumber
        )
    {
        require(address(priceFeeds[pair]) != address(0), "Pair not tracked");
        PriceInfo memory info = priceInfo[pair];
        return (
            info.chainHash,
            info.lastUpdateTimestamp,
            info.lastPrice,
            info.lastRoundId,
            info.lastUpdatedAt,
            info.lastBlockNumber
        );
    }
}
