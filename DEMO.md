# OmniStop demo video script

Target: under 3 minutes, one take, no editing required. The video is still missing; this file is the exact recording plan.

## Pre-open tabs

1. Live site: https://nassami1.github.io/omnistop/
2. Origin tx: https://sepolia.basescan.org/tx/0xee337905c0af4ab06e51df3dcf5d9c70cc3ac57956f83b542da6219e24b36389
3. Reactive tx: https://reactscan.net/tx/0x4eb6803b85a84d1f01b033e8438ab8bb733c2fc6f290cf9d9be7b4a50a05398d
4. Callback tx: https://sepolia.basescan.org/tx/0x09f1b1c36954c1185d162283d999db7a3e613c5534b6c57c25c3d10e37e1bf9a
5. README evidence: https://github.com/Nassami1/omnistop#full-loop-evidence
6. Contracts section: https://nassami1.github.io/omnistop/#contracts

## Shot list

| Time | Show | Say |
| --- | --- | --- |
| 0:00 to 0:20 | Live site hero and run ledger | "OmniStop turns a pool Sync event into an authenticated Reactive callback. The recorded full loop is 2,000 milliseconds." |
| 0:20 to 0:50 | Origin tx on Basescan | "This is the origin event on Base Sepolia. The test pair emits Sync with reserves 100e18 and 220e18, a 10 percent move." |
| 0:50 to 1:20 | Reactive tx on Reactscan | "The Lasna reactive contract filters the event, computes the reserve ratio, and emits ThresholdBreach and LatencyMeasured before requesting the callback." |
| 1:20 to 1:50 | Callback tx on Basescan | "The callback proxy calls the executor. SwapExecuted records the 2.2e18 price, the origin tx hash, and the reactive to callback leg." |
| 1:50 to 2:20 | Live site docs and risks | "The origin is MockSyncPair because Base Sepolia has no official Uniswap V2. The Reactive path is real. The swap itself is still a stub." |
| 2:20 to 2:40 | README full-loop evidence | "The full loop is 2,000 milliseconds. The on-chain leg reads 3,000 milliseconds because Lasna's clock was one second behind Base." |

## Facts to show on screen

- Reactive: `0x82d75EFbCA8e086565cB2CCEb270B0625dE6b348` on Lasna 5318007
- Executor: `0xd666DCE5C51c36D24c513AE98767229FC3fbAa40` on Base Sepolia 84532
- Pool: `0x77B728A427a331485e0B20D4cfE0ce7346D9DA83`, MockSyncPair, test-only
- Origin tx: `0xee337905c0af4ab06e51df3dcf5d9c70cc3ac57956f83b542da6219e24b36389`
- Reactive tx: `0x4eb6803b85a84d1f01b033e8438ab8bb733c2fc6f290cf9d9be7b4a50a05398d`
- Callback tx: `0x09f1b1c36954c1185d162283d999db7a3e613c5534b6c57c25c3d10e37e1bf9a`
- Full loop: `2000 ms`
- On-chain reactive leg: `3000 ms`

## Terminal commands if you want to show raw receipts

```sh
cast receipt 0xee337905c0af4ab06e51df3dcf5d9c70cc3ac57956f83b542da6219e24b36389 --rpc-url https://sepolia.base.org
cast receipt 0x4eb6803b85a84d1f01b033e8438ab8bb733c2fc6f290cf9d9be7b4a50a05398d --rpc-url https://lasna-rpc.rnk.dev/
cast receipt 0x09f1b1c36954c1185d162283d999db7a3e613c5534b6c57c25c3d10e37e1bf9a --rpc-url https://sepolia.base.org
cast block 56061286 --rpc-url https://sepolia.base.org --field timestamp
cast block 56061296 --rpc-url https://sepolia.base.org --field timestamp
```

## Do not say

- "This is a live stop order."
- "The swap executed."
- "The full loop is one second."

The result in this MVP is the authenticated `SwapExecuted` signal. No funds were swapped.

## Recording

- 1080p, browser zoom 100 percent, no keys or `.env` on screen.
- Keep the video under 3 minutes. The shot list ends at about 2:40.
