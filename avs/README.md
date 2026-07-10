# avs — Go operator/aggregator core

The off-chain half of the multi-operator BLS AVS. Every operator independently recomputes the block's
result from the relay-sealed order+intent set and BLS-signs it; the aggregator relays the stake-weighted
aggregate to `EigenAuctionTaskManager.commitWinner`; the drawn executor settles. The consensus-critical
logic is held byte-identical to the Solidity contracts and the TypeScript reference by shared golden
vectors, so what an operator signs off-chain is provably what the contract enforces on-chain.

## Binaries (`cmd/`)

Each is a thin wiring layer over `internal/*`; run them with `DEPLOYMENTS_DIR` + the env in `.env`.

| Binary | Role | Key env |
|---|---|---|
| `cmd/operator` | One operator node. Per target block: fetch the sealed set --> `operator.Resolve` (verify --> elect --> resultHash --> draw --> msgHash) --> BLS-sign --> submit to the aggregator; if it is the drawn executor, `settle` once the commit lands. Draws the executor over the on-chain operator set (`OperatorStateRetriever`); `STATIC_QUORUM=1` falls back to a single-op, no-registry dev quorum. Run N with N keysets. | `RPC_URL`, `WS_URL`, `FEED_URL`, `AGGREGATOR_URL`, `OPERATOR_PK`, `BLS_PRIVATE_KEY` |
| `cmd/aggregator` | The dumb relay. Ingests operator `SignedResponse`s over HTTP, feeds them to eigensdk's blsagg service, and once quorum stake has signed builds the `NonSignerStakesAndSignature` and submits `commitWinner`. Holds no BLS key, makes no auction decisions. | `RPC_URL`, `WS_URL`, `LISTEN_ADDR`, `AGGREGATOR_PK` |
| `cmd/register` | Onboards one operator into the AVS operator set: `RegisterAsOperator` --> optional deposit + allocate (gated on `STAKE_AMOUNT`/`STAKE_MAGNITUDE`) --> `RegisterForOperatorSets` (BLS pubkey --> APK registry). Run once per operator. | `OPERATOR_PK`, `BLS_PRIVATE_KEY`, `REWARDS_COORDINATOR`, `PERMISSION_CONTROLLER` |

Locally these run under Aspire as the `aggregator` / `operator-N` resources (`cd aspire-apphost && aspire run`);
`make register` still does the one-time onboarding. To run one directly: `cd avs && DEPLOYMENTS_DIR=... go run ./cmd/<name>`.

## Packages (`internal/`)

| Package | Role |
|---|---|
| `consensus` | Pure, byte-exact core: struct hashes, `resultHash`, `msgHash`, the executor draw, auction rule A (price-weighted net token0), and the order EIP-712 digest. No IO. Golden-vector tested against Solidity + TS. |
| `chain` | On-chain adapter: eth client (`Dial`/`Prevrandao`/`BlockNumber`), secp256k1 order recovery, `QuorumReader` (reads quorum-0 from `OperatorStateRetriever` at a reference block, sorted by id — the set the draw ranks over), abigen bindings (`bindings/settler`, `bindings/taskmanager`), and feed-->binding mappers. |
| `chaincfg` | Loads `deployments/<chainId>.json` (mirrors the TS `DeploymentArtifact`). |
| `feed` | The relay's sealed-set wire contract + HTTP client + decode. |
| `operator` | `Resolve`: the deterministic per-block pipeline that turns a sealed set into a signed result. |
| `node` | `Operator.RunBlock` — orchestrates `Resolve` around its IO edges (feed / chain / quorum / submitter) behind interfaces, plus `Operator.Settle`. Unit-tested with fakes + a real BLS key. |
| `attest` | The operator-->aggregator wire type (`SignedResponse`) + BLS sign / serialize / reconstruct. |
| `agg` | `NonSignerStakesAndSignature` mapping (blsagg response --> TaskManager calldata, incl. the G2 coordinate swap) + round tracking (`(poolId, targetBlock)` --> blsagg task index). |

## How a block flows

```
relay seals block N ── GET /auction/N ──> operator.Resolve ──> BLS-sign msgHash ──> POST /submit
                                                                                        │
                              aggregator: blsagg quorum ──> NonSignerStakesAndSignature ─┘
                                          │
                                          └─> commitWinner(...)   ┐ same block N
                                              drawn executor: settle(...) ┘
```

`msgHash = keccak256(poolId, targetBlock, resultHash, executor)` binds the executor, so operators
aggregate only if they agree on the draw — which they do, because the draw is a pure function of public
inputs (`poolId`, `targetBlock`, `resultHash`, and `prevrandao` at `referenceBlockNumber`) over the
on-chain operator set.

## Testing — three tiers, cheapest first

**Tier 1 — unit tests (no infra).** The primary loop; proves the consensus-critical logic.
```
make avs-test           # or: cd avs && go test ./...
```

**Tier 2 — cross-check vs the deployed contract (local anvil fork).** Confirms the Go core matches the
*deployed* Settler bytecode (`computeResultHash`, `DOMAIN_SEPARATOR`) — stronger than golden vectors.
Needs nothing BLS/registration-related.
```
make anvil-fork         # terminal 1: fork + local chain
make deploy-fork        # terminal 2: deploy contracts, write deployments/<CHAIN_ID>.json
make avs-integration    # run the build-tagged Tier-2 harness
```
The harness lives in `internal/chain/integration_test.go` (`//go:build integration`), so it never runs
in Tier 1 and skips cleanly if the fork env isn't wired.

**Tier 3 — full BLS flow on the mainnet fork.** All binaries against a local fork with a registered
operator set.
```
make anvil-fork                         # terminal 1: mainnet fork (also serves ws)
make fund deploy-fork seed-pool approve # terminal 2: fund + deploy + seed liquidity + approvals
make fund-operator-stake register \              # operator 1 --> operator set (repeat per operator)
  STAKE_AMOUNT=1000000000000000000 STAKE_MAGNITUDE=1000000000000000000
cd aspire-apphost && aspire run         # redis + relay + aggregator + N operators + frontend
make drive-round                        # post a batch, mine one block --> commit + settle same block
```
Same-block requirement: `commitWinner` and `settle` are both keyed to `block.number`, so they must land
in one block. `drive-round` does this locally (automine off --> wait for both --> mine one block); on
mainnet it becomes a Flashbots bundle. `post-batch` (`apps/backend/src/scripts/post-batch.ts`) is the
searcher/user driver.

## Regenerating contract bindings

After a contract ABI change, regenerate from the compiled artifact:
```
go run github.com/ethereum/go-ethereum/cmd/abigen@v1.17.4 \
  --abi <abi.json> --pkg <settler|taskmanager> --type <Settler|TaskManager> \
  --out internal/chain/bindings/<pkg>/<pkg>.go
```
(One package per contract to avoid shared-struct name collisions.)
