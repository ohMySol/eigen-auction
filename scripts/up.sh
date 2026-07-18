#!/usr/bin/env bash
# One-command local environment spin up (for the demo) for EigenAuction on a mainnet fork. Collapses the error-prone
# multi-step chain setup (anvil --> fund --> deploy --> seed --> approve --> register) into a single command,
# then — if the services are already running under `aspire run` — drives one auction round and prints the
# economic results. Otherwise it stops after chain setup and tells you to start the services.
#
# Run: make up   (needs foundry + Node/pnpm + Go, and a filled .env)
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root

val() { grep -E "^$1=" .env | cut -d= -f2- | tr -d ' '; }   # read a bare value from .env
RPC_URL="$(val RPC_URL)"
RELAY_PORT="$(val INTENT_PORT)"; RELAY_PORT="${RELAY_PORT:-8088}"
AGG_ADDR="$(val LISTEN_ADDR)";   AGG_PORT="${AGG_ADDR##*:}"; AGG_PORT="${AGG_PORT:-9090}"

# TCP liveness check via bash's /dev/tcp (no nc dependency).
tcp_up() { (exec 3<>"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1 && exec 3>&-; }

echo "▶ EigenAuction demo — local mainnet fork"

# 1) anvil fork on :8545 (start it in the background if it isn't already answering).
if cast chain-id --rpc-url "$RPC_URL" >/dev/null 2>&1; then
    echo "  ✓ chain already up at $RPC_URL"
else
    echo "  • starting anvil fork (make anvil-fork) in the background…"
    nohup make anvil-fork >/tmp/eigen-anvil.log 2>&1 &
    for _ in $(seq 1 40); do cast chain-id --rpc-url "$RPC_URL" >/dev/null 2>&1 && break; sleep 1; done
    cast chain-id --rpc-url "$RPC_URL" >/dev/null 2>&1 \
        || { echo "  ✗ anvil did not come up — see /tmp/eigen-anvil.log"; exit 1; }
    echo "  ✓ anvil fork up at $RPC_URL (logs: /tmp/eigen-anvil.log)"
fi

# 2) contracts + pool liquidity + approvals. deploy-fork rewrites deployments/<chainId>.json, so this is
#    safe to re-run on a fresh fork (a new fork wipes previously-deployed contracts).
echo "  • fund + deploy + seed pool + approve…"
make fund deploy-fork seed-pool approve

# 3) operator onboarding — three operators so a genuine multi-sig quorum forms (no single operator
#    meets the 67% threshold alone). Operator 1 is the .env keyset, already funded by `make fund`;
#    operators 2 and 3 are anvil dev accounts #5/#6 with BLS scalars 2/3 (see docs/N_OPERATORS.md),
#    funded here before registering. Equal stake keeps any one operator below quorum.
STAKE=1000000000000000000

echo "  • registering operator 1 (stake + BLS pubkey)…"
make fund-operator-stake register STAKE_AMOUNT=$STAKE STAKE_MAGNITUDE=$STAKE

# fund an extra operator (ETH + WETH + USDC), mint its stETH, then register with its distinct BLS key.
register_operator() {
    local n=$1 addr=$2 pk=$3 bls=$4
    echo "  • registering operator $n (fund + stake + BLS pubkey)…"
    make fund-operator OP="$addr"
    make fund-operator-stake register OPERATOR_PK="$pk" BLS_PRIVATE_KEY="$bls" \
        STAKE_AMOUNT=$STAKE STAKE_MAGNITUDE=$STAKE
}
register_operator 2 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc \
    0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba 2
register_operator 3 0x976EA74026E726554dB657fA54763abd0C3a0aa9 \
    0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e 3

echo "  ✓ chain ready — contracts deployed, pool seeded, operators 1–3 registered."

# 4) If the services are already running, drive a round now; otherwise point the user at `aspire run`.
if tcp_up "$RELAY_PORT" && tcp_up "$AGG_PORT"; then
    echo "  • services detected (relay :$RELAY_PORT, aggregator :$AGG_PORT) — driving one round…"
    make drive-round
else
    cat <<EOF

  Chain is ready, but the services aren't running yet. Start them, then drive a round:

      cd aspire-apphost && aspire run     # redis + relay + aggregator + operators
      make drive-round                    # posts a batch, mines the block, prints the results

  (Re-running \`make up\` once the services are up drives a round automatically.)
EOF
fi
