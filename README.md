# PriceAggregator

PriceAggregator is a decentralized Solidity contract that tracks trading pair prices by combining data from Chainlink Price Feeds with a continuously updated chain hash. Anyone can update or register a new trading pair, and each update fetches the latest on-chain price data from Chainlink, adds extra metadata (such as the Chainlink round, feed timestamp, and block number), and commits that information into a tamper-evident hash chain.

## Key Features

- **Decentralized Updates:**
  Anyone can call the update function to register a new trading pair or update an existing one. Updates are restricted to once per day per pair to prevent rapid, malicious changes.

- **Chainlink Price Feeds Integration:**
  The contract uses Chainlink Price Feeds to retrieve the latest price data, ensuring that the price information is reliable and decentralized.

- **Chain Hash Commitment:**
  Each update combines the previous chain hash with the new price data, feed timestamp, round ID, and block number. This produces a continuously chained hash that is verifiable and tamper-evident.

- **Open Tracking Mechanism:**
  The contract is fully open and does not rely on ownership. When a pair is updated, if it does not already exist, it is registered with the provided aggregator address. If it already exists, any non-zero aggregator address provided must match the registered one.

- **On-Chain Data Storage:**
  All updates are recorded on-chain. A view function (`getPriceInfo`) returns the full set of information for any tracked trading pair.

## Installation and Setup

1. **Install Foundry:**
   Follow the instructions on the [Foundry GitHub page](https://github.com/foundry-rs/foundry) to install Foundry.

2. **Clone the Repository:**

    ```bash
    git clone <repository-url>
    cd <repository-directory>
    ```

3. **Install Dependencies:**
   Make sure you have OpenZeppelin contracts installed. You can install them via Forge:

    ```bash
    forge install OpenZeppelin/openzeppelin-contracts
    ```

## Deployment

PriceAggregator is written in Solidity (^0.8.17) and can be deployed using your favorite deployment tool (e.g., Hardhat, Truffle, or Foundry's deployment scripts). An example deployment using Forge is as follows:

```bash
forge create --rpc-url <YOUR_RPC_URL> src/PriceAggregator.sol:PriceAggregator
```

## Running Tests

The tests are written using Foundry. To run the tests, execute:

```bash
forge test
```

The included tests cover:

- Registration and update of new trading pairs.
- Updating existing trading pairs after the enforced update interval.
- Reverting updates that are attempted too soon.
- Verifying that mismatched aggregator addresses cause reverts.

## Usage

- **Register/Update a Trading Pair:**
  Call the `updatePrice` function with:

- `pair`: A string identifier for the trading pair (e.g., `"ETH/USD"`).
- `aggregatorAddress`: For new pairs, provide the valid Chainlink Price Feed address; for existing pairs, you may pass `address(0)` (or the correct aggregator address).

- **View Price Information:**
  Use the `getPriceInfo` view function to retrieve the following information for a trading pair:

- Running chain hash of updates
- Timestamp of the last update
- Last price fetched
- Chainlink round ID and feed timestamp
- Block number at which the update was recorded

## Security Considerations

- **Update Frequency:**
  The contract enforces a one-day interval between updates per pair.

- **Aggregator Validation:**
  Once a trading pair is registered, any provided aggregator address during subsequent updates must match the registered one.

- **Auditing:**
  As this contract manages critical price data, extensive testing and auditing are recommended before deploying in a production environment.

## Contributing

Contributions, suggestions, and improvements are welcome. Please open an issue or submit a pull request.

## License

This project is licensed under the MIT License.
