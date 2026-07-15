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

# 3) operator onboarding (operator 1 — the .env keyset). Repeat per keyset for more operators.
echo "  • registering operator 1 (stake + BLS pubkey)…"
make fund-operator-stake register STAKE_AMOUNT=1000000000000000000 STAKE_MAGNITUDE=1000000000000000000

echo "  ✓ chain ready — contracts deployed, pool seeded, operator 1 registered."

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
