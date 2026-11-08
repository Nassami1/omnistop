# OmniStop

Reactive stop-loss and take-profit for a Uniswap V2 pool, built for the **Reactive Omni Buildathon**, **Every Second Counts** track.

A pool emits `Sync`. A reactive contract on Lasna compares the reserve ratio with the last breached price. A breach requests an authenticated callback on Base Sepolia, and the executor records the signal.

**Status:** contracts, tests, frontend, deploy scripts, and docs are complete. The live Lasna run is pending a funded testnet deployer key. No address, transaction hash, or latency number is invented in this repository.

## What is here

| Path | Purpose |
| --- | --- |
| `contracts/OmniStopReactive.sol` | Lasna contract: subscription, threshold check, callback request |
| `contracts/OmniStopExecutor.sol` | Destination contract: proxy and reactive checks, signal log |
| `contracts/ISystemContract.sol` | Minimal system and `LogRecord` interface |
| `test/OmniStop.t.sol` | Foundry tests for auth, threshold, payment hooks |
| `frontend/` | Vanilla HTML, CSS, JS evidence page |
| `scripts/deploy.sh` | Reactive first, executor second, attach executor |
| `scripts/trigger-move.sh` | Swap, wait for both transactions, measure the full loop |
| `assets/logo.png` | Supplied mark, light wordmark variant for the dark header |

## Architecture

```text
Base Sepolia 84532                          Lasna 5318007                       Base Sepolia 84532
+---------------------+   Sync event   +--------------------------+   CallbackRequest   +------------------+
| Uniswap V2 pair     | -------------> | OmniStopReactive         | ------------------> | CallbackProxy    |
| POOL_ADDRESS        |                | thresholdBps, lastPrice  |                     | 0x476F44...      |
+---------------------+                +--------------------------+                     +--------+---------+
                                                                                                |
                                                                                       executeSwap(...)
                                                                                                |
                                                                                     +----------v---------+
                                                                                     | OmniStopExecutor   |
                                                                                     +--------------------+
```

The MVP keeps the pool and the executor on the same testnet. `destChainId` is therefore also the chain used for the subscription. A cross-chain executor would need a separate origin chain id.

## Deployed addresses

No live deployment is recorded yet.

| Contract | Chain | Address |
| --- | --- | --- |
| OmniStopReactive | Lasna 5318007 | Pending |
| OmniStopExecutor | Base Sepolia 84532 | Pending |
| Origin pool | Base Sepolia 84532 | Pending |

Callback proxies (fixed protocol constants):

| Chain | Proxy |
| --- | --- |
| Base Sepolia 84532 | `0x476F44b11F5C942c58f4c8E3d0300E5710743585` |
| Unichain Sepolia 1301 | `0x775c9B990ADe401060B78D0e98684eEf8d2466C1` |

## Full-loop evidence

The table is intentionally empty until the funded run exists. The frontend reads the same values from `frontend/app.js`.

| Origin tx | Reactive tx | Callback tx | Full-loop ms |
| --- | --- | --- | --- |
| Not measured | Not measured | Not measured | Not measured |

A full loop is the origin receipt timestamp to the callback receipt timestamp. On-chain, the executor also records the reactive-to-callback leg. See [Latency method](#latency-method).

## Build and test

Requires Foundry with Solidity 0.8.20.

```sh
forge build
forge test
```

Local page:

```sh
python3 -m http.server 8000
# open http://localhost:8000/frontend/
```

The page also works when served from `frontend/` alone because `frontend/assets` links to the canonical `assets/` directory.

## Configure

```sh
cp .env.example .env
```

Fill only these required values:

| Variable | Meaning |
| --- | --- |
| `DEPLOYER_PRIVATE_KEY` | Testnet key. Never commit this file. |
| `LASNA_RPC` | `https://lasna-rpc.rnk.dev/` |
| `ORIGIN_RPC_BASE_SEPOLIA` | Base Sepolia HTTPS RPC |
| `ORIGIN_RPC_UNICHAIN_SEPOLIA` | Unichain Sepolia HTTPS RPC, only if used |
| `POOL_ADDRESS` | The Uniswap V2 pair on the chosen testnet |
| `DEST_CHAIN_ID` | `84532` or `1301` |
| `THRESHOLD_BPS` | Move in basis points, for example `50` = 0.5% |

The swap helper also needs `ROUTER_ADDRESS`, `WETH_ADDRESS`, `TOKEN_OUT`, and `AMOUNT_IN_WEI`. The router path must point at the same pair as `POOL_ADDRESS`, or the script will move a different pool and the reactive contract will not see it.

## Deploy

```sh
./scripts/deploy.sh
```

The order is deliberate:

1. Deploy `OmniStopReactive` with a zero executor.
2. Deploy `OmniStopExecutor` with the reactive address. Its signer is immutable.
3. Call `setExecutor` on the reactive contract.

The brief's order, executor first, cannot work with an immutable executor signer unless the reactive address is precomputed. The docs' order is used instead.

Fund both after deployment:

- Reactive contract: testnet REACT from the [Reactive faucet](https://dev.reactive.network/reactive-mainnet#get-testnet-react). It pays for reactive transactions.
- Executor contract: destination-chain ETH. It pays for callbacks. A failing callback still bills it.

Then run the loop:

```sh
./scripts/trigger-move.sh
```

The script performs the swap, waits for `ThresholdBreach` on Lasna and `SwapExecuted` on the destination, then prints the three hashes, the full-loop milliseconds, and a snippet for `frontend/app.js`.

## Threshold math

```text
price   = reserve1 * 1e18 / reserve0
moveBps = abs(price - lastPrice) * 10000 / lastPrice
breach  = moveBps >= thresholdBps
```

`lastPrice` starts at zero. The first `Sync` stores the baseline and returns without a callback. A breach stores the new baseline. A move inside the band does not move it, so a slow drift does not reset the stop.

The contract compares `delta * 10000 >= lastPrice * thresholdBps` to avoid an extra division. Integer math rounds down on both sides. `50` here means 50 basis points, or 0.5 percent.

## Latency method

The current `LogRecord` ABI has `txHash` and `blockNumber` but no origin block timestamp. Reading a timestamp from the reactive payload would mean inventing a field, so the on-chain contract records only what it can prove:

- Lasna: `LatencyMeasured(bytes32 indexed originTxHash, uint256 reactTs)`
- Destination: `SwapExecuted(uint256 price, bytes32 indexed originTxHash, uint256 callbackTs, uint256 reactiveToCallbackMs)`

The full loop is computed from the receipts:

```text
originTs   = origin receipt block timestamp on Base Sepolia
reactTs    = reactive receipt block timestamp on Lasna
callbackTs = callback receipt block timestamp on Base Sepolia
fullLoopMs = (callbackTs - originTs) * 1000
```

No block-number math is used on Base Sepolia. Block timestamps are second-granular, so millisecond values are second differences multiplied by 1000. This is a real constraint of EVM timestamps, not a precision claim.

The source of the brief asked for `originTs` inside `LogRecord`. The live ABI in the Reactive docs and `reactive-lib-omni` does not expose it. This repository follows the live ABI.

## Interface notes

- `subscribe` uses `uint256` topics, matching the live system contract. `REACTIVE_IGNORE` is the current `reactive-lib-omni` wildcard value, not zero.
- The callback payload reserves its first argument for the proxy-injected reactive address: `executeSwap(address,uint256,bytes32,uint256)`. The proxy replaces the placeholder. The executor checks both the proxy and the reactive signer.
- `pay(uint256)` is exposed on both contracts because the system contract and callback proxy collect fees through it. Without it, a contract can receive funds but cannot settle a bill.
- `swapViaRouter` is a single stub. `executeSwap` records the signal and does not move funds. Do not present this MVP as a live stop order.

## Security

- Testnet only: Lasna 5318007, Base Sepolia 84532, Unichain Sepolia 1301. No mainnet constants.
- `.env` is ignored. `.env.example` contains placeholders only.
- The executor accepts only the fixed callback proxy and the immutable reactive address.
- The reactive contract accepts `react` and `pay` only from the system contract.
- The executor has no withdrawal path. Funds can only be paid to the callback proxy.
- The frontend contains no keys.

## Submission checklist

| Item | Status |
| --- | --- |
| Public repo, open source, MIT | Ready to publish |
| README with track, architecture, addresses, hashes, full-loop latency | Architecture and method ready; addresses and hashes pending a funded run |
| Demo video under 3 minutes | Pending |
| Timestamps only on Base Sepolia | Pass: no block-number math |
| Lasna reactive contract, testnet only | Pass by code and config; deployment pending |
| Dim navy frontend, logo, docs section | Pass |
| No `.env` or private key committed | Verify with `git log --all -p` before submit |

## License

MIT. See [LICENSE](LICENSE).
