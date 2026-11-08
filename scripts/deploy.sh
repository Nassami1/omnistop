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
ZERO_ADDRESS=0x0000000000000000000000000000000000000000

require() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "Set $name in .env" >&2
    exit 1
  fi
}

require DEPLOYER_PRIVATE_KEY
require LASNA_RPC
require POOL_ADDRESS
require DEST_CHAIN_ID
require THRESHOLD_BPS

if ! [[ "$DEPLOYER_PRIVATE_KEY" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
  echo "DEPLOYER_PRIVATE_KEY must be a 0x-prefixed 32-byte testnet key" >&2
  exit 1
fi

if ! [[ "$POOL_ADDRESS" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
  echo "POOL_ADDRESS must be a 20-byte address" >&2
  exit 1
fi

if ! [[ "$THRESHOLD_BPS" =~ ^[0-9]+$ ]] || [ "$THRESHOLD_BPS" -lt 1 ] || [ "$THRESHOLD_BPS" -gt 10000 ]; then
  echo "THRESHOLD_BPS must be an integer from 1 to 10000" >&2
  exit 1
fi

case "$DEST_CHAIN_ID" in
  84532)
    DEST_RPC="${ORIGIN_RPC_BASE_SEPOLIA:?Set ORIGIN_RPC_BASE_SEPOLIA in .env}"
    CALLBACK_PROXY=0x476F44b11F5C942c58f4c8E3d0300E5710743585
    EXPLORER=https://sepolia.basescan.org
    ;;
  1301)
    DEST_RPC="${ORIGIN_RPC_UNICHAIN_SEPOLIA:?Set ORIGIN_RPC_UNICHAIN_SEPOLIA in .env}"
    CALLBACK_PROXY=0x775c9B990ADe401060B78D0e98684eEf8d2466C1
    EXPLORER=https://sepolia.uniscan.xyz
    ;;
  *)
    echo "DEST_CHAIN_ID must be 84532 (Base Sepolia) or 1301 (Unichain Sepolia)" >&2
    exit 1
    ;;
esac

command -v "$FORGE_BIN" >/dev/null 2>&1 || {
  echo "forge not found. Install Foundry and retry." >&2
  exit 1
}
command -v "$CAST_BIN" >/dev/null 2>&1 || {
  echo "cast not found. Install Foundry and retry." >&2
  exit 1
}

LASNA_CHAIN_ID=$("$CAST_BIN" chain-id --rpc-url "$LASNA_RPC")
if [ "$LASNA_CHAIN_ID" != "5318007" ]; then
  echo "LASNA_RPC is chain $LASNA_CHAIN_ID, expected 5318007" >&2
  exit 1
fi

DEST_CHAIN_ID_ONCHAIN=$("$CAST_BIN" chain-id --rpc-url "$DEST_RPC")
if [ "$DEST_CHAIN_ID_ONCHAIN" != "$DEST_CHAIN_ID" ]; then
  echo "Destination RPC is chain $DEST_CHAIN_ID_ONCHAIN, expected $DEST_CHAIN_ID" >&2
  exit 1
fi

"$FORGE_BIN" build

echo "Deploying OmniStopReactive on Lasna 5318007..."
REACTIVE_JSON=$(
  "$FORGE_BIN" create \
    --broadcast \
    --json \
    --rpc-url "$LASNA_RPC" \
    --private-key "$DEPLOYER_PRIVATE_KEY" \
    contracts/OmniStopReactive.sol:OmniStopReactive \
    --constructor-args "$POOL_ADDRESS" "$DEST_CHAIN_ID" "$ZERO_ADDRESS" "$THRESHOLD_BPS"
)
REACTIVE_ADDRESS=$(printf '%s' "$REACTIVE_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["deployedTo"])')

echo "Deploying OmniStopExecutor on chain $DEST_CHAIN_ID..."
EXECUTOR_JSON=$(
  "$FORGE_BIN" create \
    --broadcast \
    --json \
    --rpc-url "$DEST_RPC" \
    --private-key "$DEPLOYER_PRIVATE_KEY" \
    contracts/OmniStopExecutor.sol:OmniStopExecutor \
    --constructor-args "$CALLBACK_PROXY" "$REACTIVE_ADDRESS"
)
EXECUTOR_ADDRESS=$(printf '%s' "$EXECUTOR_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["deployedTo"])')

echo "Attaching the executor to the reactive contract..."
"$CAST_BIN" send "$REACTIVE_ADDRESS" "setExecutor(address)" "$EXECUTOR_ADDRESS" \
  --rpc-url "$LASNA_RPC" \
  --private-key "$DEPLOYER_PRIVATE_KEY" \
  >/dev/null

cat <<INFO

Deployed.
  Reactive: $REACTIVE_ADDRESS
  Executor: $EXECUTOR_ADDRESS
  Pool:     $POOL_ADDRESS
  Chain:    $DEST_CHAIN_ID
  Explorer: $EXPLORER

Add these to .env:
  REACTIVE_ADDRESS=$REACTIVE_ADDRESS
  EXECUTOR_ADDRESS=$EXECUTOR_ADDRESS

Funding:
  Reactive (REACT on Lasna): https://dev.reactive.network/reactive-mainnet#get-testnet-react
  Executor (native ETH on $DEST_CHAIN_ID): send to $EXECUTOR_ADDRESS

The callback recipient must be funded before it can pay for callbacks.
INFO
