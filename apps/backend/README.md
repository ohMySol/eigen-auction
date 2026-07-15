# Backend — the relay (avs-rpc) + drivers

The backend is the **relay**: the auction's public ingress and per-block sealer. It is the single
source of truth every operator reads. The operator and aggregator themselves are the Go AVS
([../../avs/README.md](../../avs/README.md)); this package is TypeScript.

```
src/
  avs-rpc/           the relay: Express server, Redis-backed mempools, per-block seal
  scripts/           post-batch, drive-round, approve (fork drivers)
```

## avs-rpc — the relay

Searchers and users POST signed submissions; operators GET the canonical sealed set for a block.

### Endpoints

| Method | Path | Description |
|---|---|---|
| `GET`  | `/health` | Liveness check |
| `POST` | `/order` | A searcher's EIP-712-signed arb order (`ToBOrder`) |
| `POST` | `/intent` | A user's EIP-712-signed swap intent (`SwapIntent`) |
| `GET`  | `/auction/:block` | The sealed set for a block — the canonical auction inputs |
| `GET`  | `/status` | Whether a user nonce has been consumed on-chain |

Orders and intents are signature-validated at the boundary (against the Settler's EIP-712 domain) and
queued in Redis. `POST` submissions pay no gas.

### The sealed set (`GET /auction/:block`)

This is the consensus input every operator reads. For a target block it returns:

- the **orders** scoped to that block (by `validForBlock`) and the **pending intents**,
- the **`referenceBlockNumber`** (a deterministic past block: `targetBlock - 1`),
- the **`clearingPriceX128`** — the pool's live mid read from `StateView.getSlot0` **at
  `referenceBlockNumber`**, discounted 2% for solvency (covers the pool fee + slippage).

Reading the price at the fixed `referenceBlockNumber` (not "latest") makes it deterministic: every
operator stamps the identical price regardless of when it fetches, so they can't diverge. Tracking the
live pool keeps the batch solvent as prior settles move the price (a fixed price goes stale →
`Settler_BatchInsolvent`). See [src/avs-rpc/seal.ts](src/avs-rpc/seal.ts).

### Redis

| Key | Contains | Read by |
|---|---|---|
| `orders:<poolId>`  | serialized `ToBOrder[]`  | seal endpoint (non-draining) |
| `intents:<poolId>` | serialized `SwapIntent[]` | seal endpoint (non-draining) |

Both are read without removal, so every operator receives identical bytes for a block; `validForBlock`
scopes orders to one block. `drive-round` clears these per round (the local stopgap for intent
lifecycle).

## Scripts (`src/scripts/`)

| Script | Command | Purpose |
|---|---|---|
| `post-batch.ts` | `make post-batch` | Signs competing searcher `ToBOrder`s (most LP-generous wins under rule A) + a user `SwapIntent` and POSTs them to the relay for the next block. |
| `drive-round.ts` | `make drive-round` | Orchestrates one same-block round on anvil: automine off → clear Redis → post batch → wait for commit + settle to queue → mine one block → report. |
| `approve.ts` | `make approve` | One-time: approve the Settler to pull the searchers'/user's tokens (so `settle`'s `transferFrom` succeeds). |

## Environment

Config is read from the repo-root `.env` via `@eigen-auction/shared/config`. Relay-relevant keys:

| Variable | Description |
|---|---|
| `RPC_URL` | RPC the relay reads pool state / nonces from |
| `CHAIN_ID` | 1 = mainnet fork, 11155111 = Sepolia |
| `REDIS_URL` | Redis connection string |
| `INTENT_PORT` | relay HTTP port (default 8088) |
| `FIXED_PRICE` | demo reference price used by `post-batch` to size arb orders (the relay's clearing price is the live pool mid, not this) |

## Running

**Local (via Aspire, recommended).** The AppHost runs the relay as an executable — `pnpm run start-server`
(ts-node) — alongside a plain redis container and the Go services:

```bash
cd aspire-apphost && aspire run
```

**Standalone** (the relay only; needs a redis reachable at `REDIS_URL`):

```bash
pnpm --filter @eigen-auction/backend start-server     # or dev-server for hot-reload (ts-node-dev)
```

**Deployment.** `aspire publish` generates a docker-compose stack from the AppHost (`aspire-output/`),
and `aspire deploy` builds + runs it. The stack is **redis + the relay**: the relay is built from
`docker/Dockerfile.backend`, which also builds the Vite SPA and serves it as static files, so one
container is both the intent API and the web frontend (`VITE_*` are passed as build args). The Go AVS is
excluded from the compose — it runs on operator infrastructure.

Tests: `pnpm test` (from the repo root) runs the vitest suite.
