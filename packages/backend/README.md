# Backend — AVS Operator + Searcher RPC

> **Heads up — this is outdated relative to the contracts.** The contracts have moved to the BLS
> operator-set design (a stake-weighted quorum BLS-signs each block's result, the aggregator commits
> it on-chain, and the chosen executor settles). This backend still does single-operator ECDSA
> signing in `signer.ts` and has not been ported yet. It's being updated — until then, treat the flow
> below as the legacy single-operator version. The target design is described in
> [../contracts/README.md](../contracts/README.md).

Two Node.js services that run the off-chain side of the EigenAuction loop.

```
src/backend/
  avs-auction/       Operator node — watches blocks, runs the auction, commits + settles
  avs-rpc/      HTTP API — accepts signed user intents and searcher arb bids
  shared/            Config, ABIs, types shared by both services
```

---

## avs-auction — Operator node

The operator is the EigenLayer AVS node that drives the per-block auction. It runs continuously, reacting to each new block.

### Per-block loop (`src/backend/avs-auction/index.ts`)

```
new block
   │
   ├─ 1. Read pool sqrtPriceX96 from V4 StateView
   ├─ 2. Read external (CEX) price → convert to sqrtPriceX96
   ├─ 3. Build arb swap params (direction + amountSpecified to close the gap)
   ├─ 4. Drain queued user intents from Redis
   │      skip if arb == 0 AND no intents (nothing to settle)
   ├─ 5. Drain arb bids from Redis → elect winner (highest bid wins; operator fallback at bid 0)
   ├─ 6. Sign commitment: (poolId, targetBlock, winner, bidAmount)
   ├─ 7. commitWinner() → AuctionServiceManager on-chain
   └─ 8. settle(bidAmount, arb, intents) → Settler on-chain
```

Errors in a single round are logged and swallowed so the loop survives transient RPC failures.

### Modules

**`index.ts`** — entrypoint and main loop. Exports `runBlock()` so the local demo script can drive a single round directly.

**`chain.ts`** — two state-changing transactions:
- `commitWinner(poolId, targetBlock, winner, bidAmount, signatures)` — signed by the operator key, waits for receipt
- `settle(rewardAmount, arb, intents)` — calls `Settler.settle()` as the settler-caller key, waits for receipt
- `ensureSettlerApproval(pk)` — called once on startup; approves `Settler` to spend currency0 for LP rewards (required because `Settler.settle` does `transferFrom(operator, hook, rewardAmount)`)

**`pool-price.ts`** — reads current pool state from V4 StateView:
- `getSlot0(poolId)` — returns `sqrtPriceX96` and current tick
- `buildArbParams(sqrtPriceX96, targetSqrtPrice, cap)` — computes direction and a capped `amountSpecified` to push the pool toward the target

**`cex-price.ts`** — external reference price:
- `externalPrice()` — async, returns human price (currency1 per currency0). Current implementation: reads `FIXED_PRICE` from env. Designed to be swapped for a live Binance WebSocket feed or on-chain oracle.
- `priceToSqrtX96(price, decimals0, decimals1)` — converts the human price to Uniswap's `sqrtPriceX96` using bigint integer square root (Newton's method) to preserve precision for 33-digit values.

**`bid-collector.ts`** — auction winner election:
- `collectBids(source)` — drains arb bids from the Redis queue
- `runAuction({ bids, designatedOperator })` — highest bidder wins; if no bids, the designated operator wins at `bidAmount = 0`. This ensures every block always has a settler.

**`signer.ts`** — quorum signature collection:
- `collectSignatures(operators, commitment, threshold)` — each operator signs the commitment struct; returns the array of signatures passed to `commitWinner`. For the single-operator demo, the threshold is 1.

### Startup sequence

1. Connect to Redis
2. `ensureSettlerApproval` — one-time ERC20 approval if needed
3. `watchBlockNumber` — start the per-block loop
4. Graceful shutdown on SIGTERM / SIGINT

---

## avs-rpc — HTTP API

Express server that accepts two types of off-chain submissions and queues them in Redis for the operator to drain each block.

### Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Liveness check — returns `{ ok: true }` |
| `POST` | `/intent` | Submit a signed user swap intent |
| `POST` | `/bid` | Submit a searcher arb bid |
| `GET` | `/status` | Check if a nonce has been consumed on-chain |

### User intents (`POST /intent`)

Users sign a `SwapIntent` off-chain with EIP-712 and POST it here. No gas is paid at submission time.

```typescript
SwapIntent {
  user:         address   // signer
  poolId:       bytes32
  zeroForOne:   bool
  amountIn:     uint128
  minAmountOut: uint128   // slippage protection
  nonce:        uint64    // replay protection
  deadline:     uint64
  signature:    hex
}
```

The server validates the schema and queues the intent in Redis under the pool's intent key. The operator drains this queue each block and includes the intents in `Settler.settle()`. Intents are EIP-712 signature-verified on-chain by `Settler` before execution.

**Replay protection:** `Settler` maintains a nonce bitmap per user. A used nonce is permanently invalidated. The `/status` endpoint lets the frontend check whether a nonce is still valid before signing.

### Arb bids (`POST /bid`)

Searchers (or the operator itself) can submit signed bids for the right to execute the arb swap this block:

```typescript
ArbBid {
  bidder:    address
  bidAmount: bigint   // currency0 amount paid to LPs if they win
  signature: hex
}
```

The operator drains bids each block and runs `runAuction()` to elect the highest bidder as winner. The winner is committed to the AVS and must call `Settler.settle()` — their `msg.sender` is checked against `result.winner` on-chain.

### Redis queues

| Key pattern | Contains | Drained by |
|---|---|---|
| `intents:<poolId>` | Serialised `SwapIntent[]` | Operator, each block |
| `bids:<poolId>` | Serialised `ArbBid[]` | Operator, each block |

Both queues are drained (LPOP/LRANGE + DEL) atomically each block. Undrained entries from a missed block are consumed in the next round.

---

## Shared (`src/shared/`)

**`config.ts`** — reads `.env` into typed config; exports `publicClient`, `poolKey`, `requireOperatorKeys()`.

**`abi.ts`** — ABI fragments for `EigenAuctionHook`, `Settler`, `AuctionServiceManager`, and `StateView` used by both services.

**`types.ts`** — shared TypeScript types: `SwapIntentT`, `SwapParamsT`, `IntentSource`, `BidSource`.

**`poolId.ts`** — `getPoolId(poolKey)` — deterministic `bytes32` pool ID matching V4's `PoolIdLibrary.toId()`.

**`sign.ts`** — EIP-712 domain and type definitions for `SwapIntent` signing (frontend + backend share the same type hash).

---

## Environment variables

| Variable | Used by | Description |
|---|---|---|
| `RPC_URL` | both | RPC endpoint the services connect to |
| `CHAIN_ID` | both | Chain ID (1 = mainnet fork, 11155111 = Sepolia) |
| `REDIS_URL` | both | Redis connection string |
| `DEPLOYER_PK` | avs-auction | Deployer key (also the seeded LP in the demo) |
| `OPERATOR_PK` | avs-auction | Signs `commitWinner` on the AVS |
| `SETTLER_CALLER_PK` | avs-auction | Calls `Settler.settle()` — must equal `OPERATOR_PK` |
| `PRICE_SOURCE` | avs-auction | `fixed` (reads `FIXED_PRICE`) or future oracle |
| `FIXED_PRICE` | avs-auction | Human price (currency1 per currency0) used as CEX reference |
| `INTENT_PORT` | avs-rpc | HTTP port (default 8088) |

---

## Running

```bash
# Start avs-rpc only
npm run start-server

# Start operator only
npm run start-operator

# Both via Docker (recommended for testnet)
docker compose up avs-auction avs-rpc redis
```

The Docker images are built from `docker/Dockerfile.backend`. Both services run from the same image with different `command` overrides in `docker-compose.yml`.
