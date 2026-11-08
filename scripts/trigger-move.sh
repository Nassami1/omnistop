#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "Missing .env. Copy .env.example to .env and fill it in." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

FORGE_BIN="${FORGE_BIN:-forge}"
CAST_BIN="${CAST_BIN:-cast}"

require() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "Set $name in .env" >&2
    exit 1
  fi
}

require DEPLOYER_PRIVATE_KEY
require LASNA_RPC
require REACTIVE_ADDRESS
require EXECUTOR_ADDRESS
require DEST_CHAIN_ID
require ROUTER_ADDRESS
require WETH_ADDRESS
require TOKEN_OUT
require AMOUNT_IN_WEI

for name in REACTIVE_ADDRESS EXECUTOR_ADDRESS ROUTER_ADDRESS WETH_ADDRESS TOKEN_OUT; do
  value="${!name}"
  if ! [[ "$value" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
    echo "$name must be a 20-byte address" >&2
    exit 1
  fi
done

if ! [[ "$AMOUNT_IN_WEI" =~ ^[0-9]+$ ]] || [ "$AMOUNT_IN_WEI" -eq 0 ]; then
  echo "AMOUNT_IN_WEI must be a positive integer" >&2
  exit 1
fi

case "$DEST_CHAIN_ID" in
  84532)
    DEST_RPC="${ORIGIN_RPC_BASE_SEPOLIA:?Set ORIGIN_RPC_BASE_SEPOLIA in .env}"
    EXPLORER=https://sepolia.basescan.org
    ;;
  1301)
    DEST_RPC="${ORIGIN_RPC_UNICHAIN_SEPOLIA:?Set ORIGIN_RPC_UNICHAIN_SEPOLIA in .env}"
    EXPLORER=https://sepolia.uniscan.xyz
    ;;
  *)
    echo "DEST_CHAIN_ID must be 84532 or 1301" >&2
    exit 1
    ;;
esac

command -v "$CAST_BIN" >/dev/null 2>&1 || {
  echo "cast not found. Install Foundry and retry." >&2
  exit 1
}

DEPLOYER_ADDRESS=$("$CAST_BIN" wallet address --private-key "$DEPLOYER_PRIVATE_KEY")
LASNA_START=$("$CAST_BIN" rpc eth_blockNumber --rpc-url "$LASNA_RPC" | python3 -c 'import json,sys; print(json.load(sys.stdin))')
DEST_START=$("$CAST_BIN" rpc eth_blockNumber --rpc-url "$DEST_RPC" | python3 -c 'import json,sys; print(json.load(sys.stdin))')

BREACH_TOPIC=$("$CAST_BIN" keccak "ThresholdBreach(uint256,uint256)")
CALLBACK_TOPIC=$("$CAST_BIN" keccak "SwapExecuted(uint256,bytes32,uint256,uint256)")

DEADLINE=$(( $(date +%s) + 1200 ))

echo "Swapping on chain $DEST_CHAIN_ID to move the pool..."
ORIGIN_JSON=$(
  "$CAST_BIN" send "$ROUTER_ADDRESS" \
    "swapExactETHForTokens(uint256,address[],address,uint256)" \
    0 \
    "[$WETH_ADDRESS,$TOKEN_OUT]" \
    "$DEPLOYER_ADDRESS" \
    "$DEADLINE" \
    --value "$AMOUNT_IN_WEI" \
    --rpc-url "$DEST_RPC" \
    --private-key "$DEPLOYER_PRIVATE_KEY" \
    --json
)
ORIGIN_TX=$(printf '%s' "$ORIGIN_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["transactionHash"])')
echo "Origin tx: $ORIGIN_TX"

poll_log() {
  local rpc="$1"
  local address="$2"
  local topic="$3"
  local from_block="$4"
  local filter logs tx
  filter=$(python3 -c 'import json,sys; print(json.dumps({"address": sys.argv[1], "fromBlock": sys.argv[2], "toBlock": "latest", "topics": [sys.argv[3]]}))' "$address" "$from_block" "$topic")
  for _ in $(seq 1 90); do
    logs=$("$CAST_BIN" rpc eth_getLogs "$filter" --rpc-url "$rpc" 2>/dev/null || printf '[]')
    tx=$(printf '%s' "$logs" | python3 -c 'import json,sys
try:
    rows = json.load(sys.stdin)
except Exception:
    rows = []
print(rows[0]["transactionHash"] if rows else "")' 2>/dev/null || true)
    if [ -n "$tx" ]; then
      printf '%s' "$tx"
      return 0
    fi
    sleep 2
  done
  return 1
}

echo "Waiting for the Lasna reactive transaction..."
if ! REACTIVE_TX=$(poll_log "$LASNA_RPC" "$REACTIVE_ADDRESS" "$BREACH_TOPIC" "$LASNA_START"); then
  echo "No ThresholdBreach found after 3 minutes." >&2
  echo "Check that the reactive contract is funded and the swap moved the pool past THRESHOLD_BPS." >&2
  exit 1
fi

echo "Waiting for the callback transaction..."
if ! CALLBACK_TX=$(poll_log "$DEST_RPC" "$EXECUTOR_ADDRESS" "$CALLBACK_TOPIC" "$DEST_START"); then
  echo "No SwapExecuted found after 3 minutes." >&2
  echo "Check the executor funding and the callback proxy address for chain $DEST_CHAIN_ID." >&2
  exit 1
fi

tx_timestamp() {
  local rpc="$1"
  local tx="$2"
  local block
  block=$("$CAST_BIN" rpc eth_getTransactionReceipt "$tx" --rpc-url "$rpc" | python3 -c 'import json,sys; print(json.load(sys.stdin)["blockNumber"])')
  "$CAST_BIN" rpc eth_getBlockByNumber "$block" false --rpc-url "$rpc" | python3 -c 'import json,sys; print(int(json.load(sys.stdin)["timestamp"], 16))'
}

ORIGIN_TS=$(tx_timestamp "$DEST_RPC" "$ORIGIN_TX")
REACT_TS=$(tx_timestamp "$LASNA_RPC" "$REACTIVE_TX")
CALLBACK_TS=$(tx_timestamp "$DEST_RPC" "$CALLBACK_TX")
FULL_LOOP_MS=$(( (CALLBACK_TS - ORIGIN_TS) * 1000 ))
REACTIVE_LEG_MS=$(( (CALLBACK_TS - REACT_TS) * 1000 ))
MEASURED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cat <<INFO

Full loop measured.
  Origin tx:    $ORIGIN_TX
  Reactive tx:  $REACTIVE_TX
  Callback tx:  $CALLBACK_TX
  Full loop:    ${FULL_LOOP_MS} ms (origin receipt -> callback receipt)
  Reactive leg: ${REACTIVE_LEG_MS} ms (react receipt -> callback receipt)
  Origin block timestamp:   $ORIGIN_TS
  Reactive block timestamp: $REACT_TS
  Callback block timestamp: $CALLBACK_TS
  Measured at: $MEASURED_AT

Paste into frontend/app.js:
  originTx: "$ORIGIN_TX",
  reactiveTx: "$REACTIVE_TX",
  callbackTx: "$CALLBACK_TX",
  fullLoopMs: $FULL_LOOP_MS,
  measuredAt: "$MEASURED_AT"

Explorer: $EXPLORER
INFO
