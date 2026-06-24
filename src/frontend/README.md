# Frontend — LP Dashboard + Trade UI

> **Heads up — this is outdated relative to the contracts.** The contracts have moved to the BLS
> operator-set design, so the deployment artifacts, ABIs, and some flows referenced here are ahead of
> what this app wires up. It's being updated to match — until then, expect parts of the UI to lag the
> current contracts. See [../contracts/README.md](../contracts/README.md) for the current on-chain design.

React SPA built with Vite. Connects to the deployed contracts via wagmi/viem. Falls back to a fully functional mock data layer when no deployment artifact is present, so the UI works for design work without a chain.

```
src/frontend/
  app/
    chain/           wagmi config, hooks, ABIs, deployment artifact loader, V4 math
    app.jsx          App shell: nav, wallet, block sim, theme tweaks
    viewDashboard.jsx  LP Dashboard — position, rewards, rebate chart
    viewPool.jsx     Pool Stats (Coming Soon placeholder)
    viewTrade.jsx    Trade — submit signed swap intents
    viewHome.jsx     Landing page with live LVR stats
    liquidityModal.jsx  Add / remove liquidity flows
    ui.jsx           Design system: Card, Stat, Pill, TokenRow, AreaChart, Icon, Btn
    data.js          Mock seed data, event generator, formatting helpers
    tweaks-panel.jsx Theme controls (accent, mode, density, font)
  index.html
  vite.config.js
```

---

## Deployment artifact

All chain addresses are read from `deployments/<chainId>.json`, written by the deploy script. The file is loaded at Vite **build time** via `import.meta.glob`.

**`src/frontend/app/chain/deployment.js`**

```js
export const CHAIN_ID  = Number(import.meta.env.VITE_CHAIN_ID ?? "11155111");
export const DEPLOYMENT = byChainId[String(CHAIN_ID)] ?? null;
export const IS_LIVE    = DEPLOYMENT != null;
export const IS_TESTNET = IS_LIVE && CHAIN_ID !== 1;  // gates Faucet button
export const POOL_KEY   = ...                          // assembled from artifact
```

`IS_LIVE` is the single flag that controls live vs mock data throughout the app. When false (no artifact), every chain read is disabled and mock seed data is shown instead.

`VITE_CHAIN_ID` and `VITE_RPC_URL` are baked into the JS bundle at build time — changing them requires a rebuild.

---

## Chain hooks (`src/frontend/app/chain/hooks.js`)

All contract reads are gated on `IS_LIVE` and refetch every 12 seconds (one block).

### Read hooks

**`usePoolPrice()`** — reads `StateView.getSlot0(poolId)`. Returns `sqrtPriceX96`, `tick`, and `price` (human currency1/currency0).

**`usePositionLiquidity(account)`** — reads `hook.positionLiquidity(poolKey, account, lower, upper, salt)`. Returns the raw `uint128` liquidity for the full-range position.

**`usePoolLiquidity()`** — reads `StateView.getLiquidity(poolId)`. Returns total active liquidity in the pool.

**`useEarned(account)`** — reads `hook.earned(poolKey, account, lower, upper, salt)`. Returns `{ amount, dec }` — pending LVR rewards in currency0.

**`usePositionAmounts(account)`** — derived hook combining position liquidity + pool price + pool liquidity:
- Calls `getAmountsForLiquidity(sqrtPriceX96, sqrtA, sqrtB, posLiquidity)` to compute token amounts
- Returns `{ amount0Human, amount1Human, poolShareBps, posLiquidity, valueC0, poolPrice }`
- Returns `null` when no live position exists (no position = zero liquidity)

**`useChainInfo()`** — real block number + chain name from the connected wallet's chain:
```js
{ blockNumber: Number | null, chainName: string }
// e.g. { blockNumber: 7654321, chainName: "Sepolia" }
```

**`useTokenBalances(account)`** — ERC20 `balanceOf` for both pool currencies.

### Write hooks

**`useAddLiquidity()`** — `hook.addLiquidity(key, lower, upper, liquidity)`:
1. Reads current `sqrtPriceX96` from StateView
2. Calls `getLiquidityForAmounts` to compute the optimal `uint128` liquidity
3. Approves both tokens if needed
4. Calls `hook.addLiquidity`

**`useRemoveLiquidity()`** — `hook.removeLiquidity(key, lower, upper, liquidity)`. Hook automatically pays out `earned()` in the same transaction.

**`useFaucet()`** — calls `FaucetToken.faucet()` for both pool tokens. Visible only when `IS_TESTNET`.

**`useSubmitIntent()`** — EIP-712 sign + POST to `searcher-rpc`:
1. Generates a random 64-bit nonce (CSPRNG)
2. Signs `SwapIntent` with `signTypedData` (MetaMask popup — no gas)
3. POSTs the serialised intent to `INTENT_URL/intent`
4. Returns `isPending` state for both signing and posting phases

---

## V4 math (`src/frontend/app/chain/v4Math.js`)

Pure bigint implementations — no floating point — matching Uniswap V4's Solidity exactly.

**`getSqrtRatioAtTick(tick)`** — Solidity `TickMath.getSqrtPriceAtTick` ported to JS bigint.

**`getLiquidityForAmounts(sqrtP, sqrtA, sqrtB, amount0, amount1)`** — inverse of getAmountsForLiquidity; used by `useAddLiquidity` to size the position.

**`getAmountsForLiquidity(sqrtP, sqrtA, sqrtB, liquidity)`** — computes token amounts from liquidity + price range. Used by `usePositionAmounts` to display real token amounts.

**`priceFromSqrtX96(sqrtPriceX96, dec0, dec1)`** — converts raw sqrtPriceX96 to a human price (currency1 per currency0), accounting for decimal differences.

---

## Views

### LP Dashboard (`viewDashboard.jsx`)

Three-state display logic for "Your Position":

| State | Condition | Shows |
|---|---|---|
| Mock / offline | `!IS_LIVE` | Seed data from `data.js` |
| Live, no position | `IS_LIVE && livePos == null` | Zeros, "○ no position" pill, no Remove button |
| Live, has position | `IS_LIVE && livePos != null` | Real on-chain amounts from `usePositionAmounts` |

Pending rewards read from `hook.earned()` live. Rewards are auto-paid on remove — no separate claim button.

### Trade (`viewTrade.jsx`)

1. User enters swap direction and amount
2. `useSubmitIntent` signs EIP-712 intent (wallet popup, zero gas)
3. Intent is queued in searcher-rpc → operator bundles it with the next arb settlement
4. User sees their swap filled at the post-arb price in the next block

### Pool Stats (`viewPool.jsx`)

Coming Soon placeholder. Planned: live price vs CEX chart, LVR-per-block bar chart, `ArbitrageSettled` event feed.

### Home (`viewHome.jsx`)

Landing page showing live-simulated (or real, when `IS_LIVE`) total LVR captured and arb event feed.

---

## Mock data layer (`data.js`)

When `IS_LIVE = false`, the app runs a full simulation:
- 12-second block timer drives fake price jitter + arb events
- `EA.seed` provides initial pool state (price, liquidity, LP position)
- `EA.HISTORY` is 30 days of cumulative reward data for the area chart
- `EA.makeEvent()` generates realistic `ArbitrageSettled`-style events

This lets judges and designers explore the full UI without a live chain.

---

## Theme system

Runtime theme tokens are set on `document.documentElement` via CSS custom properties. The Tweaks Panel (gear icon, bottom-left) exposes:

| Control | Options |
|---|---|
| Accent colour | 5 presets + custom hex |
| Mode | dark / light |
| Density | compact / regular / comfy |
| UI font | Space Grotesk / Geist / IBM Plex Sans |

---

## Building

```bash
# Development (hot reload)
npm run frontend

# Production bundle → src/frontend/dist/
npm run frontend:build

# Docker (Vite args baked in at build time)
docker compose build frontend
```

The Docker image (`docker/Dockerfile.frontend`) runs Vite build with `VITE_CHAIN_ID`, `VITE_RPC_URL`, and `VITE_INTENT_URL` as build args, then serves `dist/` via nginx on port 8080.

**Important:** `VITE_*` variables are baked into the bundle at build time. After a redeploy (new `deployments/<chainId>.json`) or env change, rebuild the frontend image:

```bash
docker compose build frontend && docker compose up -d frontend
```

---

## wagmi config (`src/frontend/app/chain/wagmi.js`)

Configured for injected wallets (MetaMask, etc.). Supports Ethereum mainnet, Sepolia, Base, Base Sepolia, and Anvil (local). The transport uses `VITE_RPC_URL` if set, otherwise falls back to the public Sepolia endpoint.
