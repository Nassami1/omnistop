# OmniStop acceptance verification

Date: 2026-11-08

Repo: https://github.com/Nassami1/omnistop

Live site: https://nassami1.github.io/omnistop/

Run: reactive `0x82d75EFbCA8e086565cB2CCEb270B0625dE6b348`, executor `0xd666DCE5C51c36D24c513AE98767229FC3fbAa40`, pool `0x77B728A427a331485e0B20D4cfE0ce7346D9DA83`.

## Build and tests

```text
$ forge build
exit 0. Only lint warnings.

$ forge test
Ran 5 tests for test/OmniStop.t.sol:OmniStopTest
[PASS] testExecutorGuards()
[PASS] testNoExecutorKeepsBaseline()
[PASS] testOnlySystem()
[PASS] testPayGuards()
[PASS] testThresholdAndBaseline()
Suite result: ok. 5 passed; 0 failed; 0 skipped.
```

Evidence: `contracts/OmniStopReactive.sol`, `contracts/OmniStopExecutor.sol`, `test/OmniStop.t.sol`.

## Required greps

```text
$ grep -rn "block.number" contracts/ test/ scripts/ frontend/
(no output)

$ grep -rn "0x000000000000000000000000000000000000fffFfF\|vmOnly\|emit Callback" contracts/ test/ scripts/ frontend/
(no output)

$ grep -rn "cdn\|import " frontend/
(no output)

$ git log --all -p | grep -c "$KEY_PREFIX"
0

$ git ls-files | grep "^\.env$"
(no output)
```

Evidence: `contracts/OmniStopReactive.sol:70` uses `block.timestamp`; `contracts/OmniStopExecutor.sol:35` uses `block.timestamp`; `.gitignore:1` ignores `.env`.

## Frontend serve check

Frontend serve check, using the README Quickstart command from the repo root:

```text
title: OmniStop | Reactive stop-loss, measured
h1: 1
status: Measured 2026-11-08T10:35:28Z
contracts: 3 addresses populated
latency: 2,000 ms
consoleErrors: []
pageErrors: []
badResponses: []
```

Evidence: `frontend/index.html`, `frontend/styles.css`, `frontend/app.js`.

## Phase 4 pass or fail

| Box | Result | Evidence |
| --- | --- | --- |
| Public repo, open source, built during event | PASS | https://github.com/Nassami1/omnistop, `LICENSE`, commits dated 2026-11-08 |
| README with track, architecture, addresses, hashes, full-loop latency | PASS | `README.md` "Status" and "Full-loop evidence" |
| Deployed addresses and 3 hashes | PASS | `README.md` "Deployed addresses" and "Full-loop evidence" |
| Full-loop latency number | PASS | `README.md` "Full-loop evidence", `frontend/app.js` `DEPLOYED`, live site run ledger |
| Demo video under 3 minutes | PASS | `demo/omnistop-demo.mp4`, 2:06, 1920x1080, captioned; script in `DEMO.md` |
| Timestamps only, no block.number | PASS | grep output is empty; `contracts/OmniStopReactive.sol:70`, `contracts/OmniStopExecutor.sol:35` |
| Lasna reactive, testnet only | PASS | Reactive address on Lasna 5318007; callback proxy `0x476F44...`; no mainnet constants |
| Dim navy frontend, logo, docs | PASS | `frontend/styles.css:5`, `frontend/index.html:18`, `frontend/index.html:204`, live site |
| No `.env` or key committed | PASS | `.gitignore:1`, `git ls-files` output empty, secret history scan 0 |
| DoraHacks submission complete | FAIL | Video is ready; DoraHacks upload not done |

**Phase 4 is complete on the repository side.** The video requirement is met by `demo/omnistop-demo.mp4`. The only remaining step is the DoraHacks upload, which needs the owner account. The submission is not marked done until that upload exists.
