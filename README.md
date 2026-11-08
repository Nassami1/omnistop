# OmniStop

Reactive stop-loss and take-profit for a Uniswap V2 pool, built for the **Reactive Omni Buildathon**, **Every Second Counts** track.

A pool emits `Sync`. A reactive contract on Lasna compares the reserve ratio with the last breached price. A breach requests an authenticated callback on Base Sepolia, and the executor records the signal.

**Status:** live on Base Sepolia and Lasna. The full loop is recorded below. The demo video is recorded at `demo/omnistop-demo.mp4` (2:06, captioned). The DoraHacks upload is still pending.

**Live site:** [https://nassami1.github.io/omnistop/](https://nassami1.github.io/omnistop/)

**Verification:** [VERIFICATION.md](VERIFICATION.md). **Demo script:** [DEMO.md](DEMO.md). **Demo video:** [demo/omnistop-demo.mp4](demo/omnistop-demo.mp4).

## Quickstart (local dashboard, 2 minutes)

Prerequisites: `git` and `python3` for the dashboard. Foundry `forge` and `cast` are only needed to build or re-run (`forge build`, `forge test`, `./scripts/deploy.sh`, `./scripts/trigger-move.sh`).

```sh
git clone https://github.com/Nassami1/omnistop.git
cd omnistop
cp .env.example .env   # fill only to deploy; not needed to view the dashboard
python3 -m http.server 8000
# open http://localhost:8000/frontend/
```

Use a testnet key only. Never commit `.env`.

## What is here

| Path | Purpose |
| --- | --- |
| `contracts/OmniStopReactive.sol` | Lasna contract: subscription, threshold check, callback request |
| `contracts/OmniStopExecutor.sol` | Destination contract: proxy and reactive checks, signal log |
| `contracts/ISystemContract.sol` | Minimal system and `LogRecord` interface |
| `test/OmniStop.t.sol` | Foundry tests for auth, threshold, payment hooks |
| `test/MockSyncPair.sol` | Test-only origin that emits the Uniswap V2 `Sync` shape |
| `frontend/` | Vanilla HTML, CSS, JS evidence page |
| `scripts/deploy.sh` | Reactive first, executor second, attach executor |
| `scripts/trigger-move.sh` | Swap, wait for both transactions, measure the full loop |
| `assets/logo.png` | Supplied mark, light wordmark variant for the dark header |
| `demo/omnistop-demo.mp4` | Captioned 2:06 evidence walkthrough |

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

Base Sepolia has no official Uniswap V2 deployment. The live run uses `MockSyncPair`, which emits the same `Sync(uint112,uint112)` event. The Reactive and callback path is identical to a real V2 pair. The pair address is `0x77B728A427a331485e0B20D4cfE0ce7346D9DA83`.

## Deployed addresses

Live on Base Sepolia and Lasna.

| Contract | Chain | Address |
| --- | --- | --- |
| OmniStopReactive | Lasna 5318007 | [0x82d75EFbCA8e086565cB2CCEb270B0625dE6b348](https://lasna.reactscan.net/address/0x82d75EFbCA8e086565cB2CCEb270B0625dE6b348) |
| OmniStopExecutor | Base Sepolia 84532 | [0xd666DCE5C51c36D24c513AE98767229FC3fbAa40](https://sepolia.basescan.org/address/0xd666DCE5C51c36D24c513AE98767229FC3fbAa40) |
| Origin pool, MockSyncPair | Base Sepolia 84532 | [0x77B728A427a331485e0B20D4cfE0ce7346D9DA83](https://sepolia.basescan.org/address/0x77B728A427a331485e0B20D4cfE0ce7346D9DA83) |

Callback proxies (fixed protocol constants):

| Chain | Proxy |
| --- | --- |
| Base Sepolia 84532 | `0x476F44b11F5C942c58f4c8E3d0300E5710743585` |
| Unichain Sepolia 1301 | `0x775c9B990ADe401060B78D0e98684eEf8d2466C1` |

## Full-loop evidence

Recorded on 2026-11-08. The frontend reads the same values from `frontend/app.js`.

| Origin tx | Reactive tx | Callback tx | Full-loop ms |
| --- | --- | --- | --- |
| [0xee337905c0af4ab06e51df3dcf5d9c70cc3ac57956f83b542da6219e24b36389](https://sepolia.basescan.org/tx/0xee337905c0af4ab06e51df3dcf5d9c70cc3ac57956f83b542da6219e24b36389) | [0x4eb6803b85a84d1f01b033e8438ab8bb733c2fc6f290cf9d9be7b4a50a05398d](https://lasna.reactscan.net/tx/0x4eb6803b85a84d1f01b033e8438ab8bb733c2fc6f290cf9d9be7b4a50a05398d) | [0x09f1b1c36954c1185d162283d999db7a3e613c5534b6c57c25c3d10e37e1bf9a](https://sepolia.basescan.org/tx/0x09f1b1c36954c1185d162283d999db7a3e613c5534b6c57c25c3d10e37e1bf9a) | 2,000 ms |

| Run field | Value |
| --- | --- |
| Origin block | 56061286, timestamp 1794134126 |
| Reactive block | 7832528, timestamp 1794134125 |
| Callback block | 56061296, timestamp 1794134128 |
| Gas used | 28,353 / 93,743 / 73,700 |
| On-chain reactive leg | 3,000 ms, from the `SwapExecuted` event |
| Price at breach | 2.2e18, a 10 percent move from the 2.0e18 baseline |

A full loop is the origin receipt timestamp to the callback receipt timestamp. On-chain, the executor also records the reactive-to-callback leg. Lasna's timestamp was one second behind Base in this run, so the on-chain leg reads 3,000 ms while the same-chain full loop is 2,000 ms. See [Latency method](#latency-method).

## Build and test

Requires Foundry with Solidity 0.8.20.

```sh
forge build
forge test
```

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

For the live Base Sepolia test pair, the two origin events were emitted with `setReserves` instead of a router swap:

```sh
cast send $POOL_ADDRESS "setReserves(uint112,uint112)" 100000000000000000000 200000000000000000000 --rpc-url $ORIGIN_RPC_BASE_SEPOLIA --private-key $DEPLOYER_PRIVATE_KEY
# wait until lastPrice() on OmniStopReactive is 2e18
cast send $POOL_ADDRESS "setReserves(uint112,uint112)" 100000000000000000000 220000000000000000000 --rpc-url $ORIGIN_RPC_BASE_SEPOLIA --private-key $DEPLOYER_PRIVATE_KEY
```

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

Lasna and Base clocks are independent. In the recorded run Lasna was one second behind Base, so the on-chain leg is 3,000 ms and the same-chain full loop is 2,000 ms. The full-loop number is the one in the evidence table.

The source of the brief asked for `originTs` inside `LogRecord`. The live ABI in the Reactive docs and `reactive-lib-omni` does not expose it. This repository follows the live ABI.

## Interface notes

- `subscribe` uses `uint256` topics, matching the live system contract. `REACTIVE_IGNORE` is the current `reactive-lib-omni` wildcard value, not zero.
- The callback payload reserves its first argument for the proxy-injected reactive address: `executeSwap(address,uint256,bytes32,uint256)`. The proxy replaces the placeholder. The executor checks both the proxy and the reactive signer.
- `pay(uint256)` is exposed on both contracts because the system contract and callback proxy collect fees through it. Without it, a contract can receive funds but cannot settle a bill.
- `swapViaRouter` is a single stub. `executeSwap` records the signal and does not move funds. Do not present this MVP as a live stop order.
- The `Sync` topic is the canonical `keccak256("Sync(uint112,uint112)")`, `0x1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad1`. An earlier value in the project did not match the ABI; the canonical hash is used so subscriptions fire.

## Design notes

- Navy field and blue actions come from the brief. Purple marks the Reactive layer. Gold comes from the supplied mark and is reserved for the threshold breach and focus.
- Mono is limited to chain data, addresses, and timings, where alignment matters. Body copy uses a neutral sans.
- The page is built as a ledger: section indices, a threshold gauge, a run table, and a docs index. The three-stage loop is the actual contract path, not a template section.

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
| Public repo, open source, MIT | Pass: public at https://github.com/Nassami1/omnistop |
| README with track, architecture, addresses, hashes, full-loop latency | Pass: live addresses, hashes, and 2,000 ms recorded |
| Demo video under 3 minutes | PASS: [demo/omnistop-demo.mp4](demo/omnistop-demo.mp4), 2:06, captioned; same table at https://nassami1.github.io/omnistop/ |
| DoraHacks submission complete | FAIL: video ready; DoraHacks upload not done |
| Timestamps only on Base Sepolia | Pass: no block-number math |
| Lasna reactive contract, testnet only | Pass: live on Lasna 5318007 |
| Live frontend URL | Pass: https://nassami1.github.io/omnistop/ |
| Dim navy frontend, logo, docs section | Pass |
| No `.env` or private key committed | Pass: no `.env` in tracked files or git history |

## License

MIT. See [LICENSE](LICENSE).
