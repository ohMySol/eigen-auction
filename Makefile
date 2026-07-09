# EigenAuction LVR hook — local + testnet development stack.
#
# ── Sepolia testnet (judges / live demo) ─────────────────────────────────────────────────
#   1. Fill .env (SEPOLIA_RPC_URL, DEPLOYER_PK, OPERATOR_PK, CHAIN_ID=11155111, RPC_URL=SEPOLIA_RPC_URL)
#   2. make deploy-testnet                # deploys contracts, writes deployments/11155111.json
#   3. export VITE_RPC_URL=<sepolia_rpc> VITE_CHAIN_ID=11155111
#   4. make up                            # builds + starts all 4 containers → http://localhost:8080
#
# ── Local mainnet fork (development) ─────────────────────────────────────────────────────
#   make anvil-fork                       # terminal 1: fork mainnet (chainId 1)
#   make fund deploy-fork                 # terminal 2: fund + deploy (seed LP via a V4 router/PositionManager)
#   docker compose up -d redis
#   make start-server                     # avs-rpc
#   make demo                             # one-shot arb demo
#   make demo-full                        # full narrated demo (bids → auction → LP claim)
#   make frontend-dev                     # Vite dev server with hot-reload
#
# Required in .env: MAINNET_RPC_URL, SEPOLIA_RPC_URL, DEPLOYER_PK, OPERATOR_PK, SETTLER_CALLER_PK,
#                   RPC_URL, CHAIN_ID, REDIS_URL
include .env
export

CONTRACTS := src/contracts
# Anvil default account #0 (deployer) and #1 (operator) — override via .env for real keys.
ANVIL_DEPLOYER ?= 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
ANVIL_OPERATOR ?= 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
# Searchers for the full demo (anvil accounts #2-#4; keys hardcoded in full-demo.ts).
SEARCHERS := 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC 0x90F79bf6EB2c4f870365E785982E1f101E93b906 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
USDC := 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
WETH := 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
# Lido stETH — the operator set stake token (config/networks/1.json .eigenlayer.stakeToken).
STETH := 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84
# 1,000,000 USDC (6dp) as a 32-byte storage word.
USDC_BAL := 0x000000000000000000000000000000000000000000000000000000e8d4a51000
# 5000 WETH (18dp) as a 32-byte storage word.
WETH_BAL := 0x00000000000000000000000000000000000000000000010f0cf064dd59200000
# 10000 ETH.
ETH_BAL := 0x21e19e0c9bab2400000

.PHONY: anvil-fork fund deploy-fork seed deploy-testnet start-server start-operator demo demo-full build test avs-test avs-integration fund-stake register approve start-aggregator start-operator-go post-batch drive-round frontend-dev frontend-build up

## Start a mainnet fork. --auto-impersonate lets fund targets send from whales without unlocking each.
anvil-fork:
	anvil --fork-url $(MAINNET_RPC_URL) --auto-impersonate --chain-id 1

## Fund deployer + operator with ETH, USDC and WETH. The deployer is the LP + intent user; the
## operator funds the arb swap. ERC20 balances are set directly via anvil_setStorageAt at each
## token's balanceOf slot (WETH: slot 3, USDC implementation: slot 9) — deterministic, no whales.
## Balances: WETH 0x...920000 = 5000e18, USDC 0x...e8d4a51000 = 1,000,000e6.
fund:
	cast rpc anvil_setBalance $(ANVIL_DEPLOYER) 0x21e19e0c9bab2400000 --rpc-url $(RPC_URL)
	cast rpc anvil_setBalance $(ANVIL_OPERATOR) 0x21e19e0c9bab2400000 --rpc-url $(RPC_URL)
	@echo "Funding deployer + operator with WETH (slot 3)..."
	cast rpc anvil_setStorageAt $(WETH) $$(cast index address $(ANVIL_DEPLOYER) 3) \
		0x00000000000000000000000000000000000000000000010f0cf064dd59200000 --rpc-url $(RPC_URL)
	cast rpc anvil_setStorageAt $(WETH) $$(cast index address $(ANVIL_OPERATOR) 3) \
		0x00000000000000000000000000000000000000000000010f0cf064dd59200000 --rpc-url $(RPC_URL)
	@echo "Funding deployer + operator with USDC (slot 9)..."
	cast rpc anvil_setStorageAt $(USDC) $$(cast index address $(ANVIL_DEPLOYER) 9) $(USDC_BAL) --rpc-url $(RPC_URL)
	cast rpc anvil_setStorageAt $(USDC) $$(cast index address $(ANVIL_OPERATOR) 9) $(USDC_BAL) --rpc-url $(RPC_URL)
	@echo "Funding searchers with ETH + USDC..."
	@for a in $(SEARCHERS); do \
		cast rpc anvil_setBalance $$a $(ETH_BAL) --rpc-url $(RPC_URL); \
		cast rpc anvil_setStorageAt $(USDC) $$(cast index address $$a 9) $(USDC_BAL) --rpc-url $(RPC_URL); \
	done

## Deploy our 3 contracts + register operator + init pool; writes deployments/<CHAIN_ID>.json. Uses the
## canonical config-driven Deploy script against the fork RPC (chainId 1 = mainnet fork, real tokens).
deploy-fork:
	forge script $(CONTRACTS)/script/Deploy.s.sol \
		--root $(CONTRACTS) --rpc-url $(RPC_URL) --broadcast -vvv

## Seed the deployed pool with a full-range LP position so settle's arb + batch swaps have liquidity.
## Run once after deploy-fork + fund (the deployer must hold currency0/currency1).
seed:
	forge script $(CONTRACTS)/script/SeedLiquidity.s.sol \
		--root $(CONTRACTS) --rpc-url $(RPC_URL) --broadcast -vvv

## Deploy the full system to Sepolia: FaucetTokens + protocol + real EigenLayer operator registration
## + seeded LP. Writes deployments/11155111.json. Requires SEPOLIA_RPC_URL, DEPLOYER_PK, OPERATOR_PK
## (both funded with Sepolia ETH). Append `--verify` with ETHERSCAN_API_KEY set to verify on Etherscan.
deploy-testnet:
	forge script $(CONTRACTS)/script/DeployTestnet.s.sol \
		--root $(CONTRACTS) --rpc-url $(SEPOLIA_RPC_URL) --broadcast -vvv

build:
	forge build --root $(CONTRACTS)

test:
	pnpm test

## Fast, infra-free Go unit tests for the AVS core (consensus, chain, feed, operator).
avs-test:
	cd avs && go test ./...

## Mint stETH to the operator by submitting its own (funded) ETH to Lido, so `make register` can
## deposit real stake into the stETH strategy. stETH mints ~1:1 with ETH; 2 ETH → ~2 stETH.
fund-stake:
	cast send $(STETH) "submit(address)" 0x0000000000000000000000000000000000000000 \
		--value 2ether --private-key $(OPERATOR_PK) --rpc-url $(RPC_URL)

## Register this operator into the AVS operator set (BLS pubkey → APK registry). Run once per operator
## with its OPERATOR_PK + BLS_PRIVATE_KEY, after deploy-fork. Set STAKE_AMOUNT to also deposit + allocate
## (run `make fund-stake` first to give the operator stETH).
register:
	cd avs && DEPLOYMENTS_DIR=$(PWD)/deployments go run ./cmd/register

## Run the Go aggregator: collects operator BLS sigs, aggregates, submits commitWinner. Needs WS_URL.
start-aggregator:
	cd avs && DEPLOYMENTS_DIR=$(PWD)/deployments go run ./cmd/aggregator

## Run a Go operator node: seals → resolves → BLS-signs → submits, and settles if drawn. Run N with N keysets.
start-operator-go:
	cd avs && DEPLOYMENTS_DIR=$(PWD)/deployments go run ./cmd/operator

## Approve the Settler to pull tokens from the searchers + user (one-time, after deploy/fund). Needed
## so settle's transferFrom succeeds. Idempotent.
approve:
	pnpm approve

## Post a batch of searcher orders + a user intent to the relay for the next target block, then mine.
post-batch:
	pnpm post-batch

## Orchestrate one full same-block round: automine off → post batch → wait for commit+settle to queue
## → mine the target block → report. Prereqs: start-server + start-aggregator + start-operator-go running.
drive-round:
	pnpm drive-round

## Tier-2 harness: cross-check the Go core against the DEPLOYED Settler on the running fork.
## Prereqs: `make anvil-fork` (terminal 1) + `make deploy-fork` (terminal 2) done.
avs-integration:
	cd avs && DEPLOYMENTS_DIR=$(PWD)/deployments CHAIN_ID=$(CHAIN_ID) RPC_URL=$(RPC_URL) \
		go test -tags integration -run Deployed -v ./internal/chain/

start-server:
	pnpm start-server

start-operator:
	pnpm start-operator

demo:
	pnpm demo

## Full narrated end-to-end demo. Prereqs: deploy-fork done + LP seeded via a router, redis + start-server up.
demo-full:
	pnpm demo:full

## Run the frontend in dev mode with hot-reload (reads deployments/<CHAIN_ID>.json live).
frontend-dev:
	pnpm frontend

## Build the production frontend bundle into apps/frontend/dist/.
frontend-build:
	pnpm frontend:build

## Start the full docker stack (all 4 services). Prereqs: deploy-testnet done, .env populated.
## Open http://localhost:8080 after this completes.
up:
	docker compose up --build
