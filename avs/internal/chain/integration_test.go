//go:build integration

// Tier-2 harness: cross-checks the Go consensus core against the DEPLOYED Settler on a local anvil
// fork — a stronger guarantee than the golden vectors, since it hashes through the real contract
// bytecode. Needs nothing BLS/registration-related: computeResultHash and DOMAIN_SEPARATOR are
// pure/view, so only the Settler address is required.
//
// Run it against a running fork with contracts deployed:
//
//	make anvil-fork          # terminal 1
//	make deploy-fork         # terminal 2 (writes deployments/<CHAIN_ID>.json)
//	make avs-integration     # runs this file
//
// It skips (not fails) when the env isn't wired, so a bare `go test -tags integration ./...` is safe.
package chain

import (
	"context"
	"encoding/hex"
	"math/big"
	"os"
	"strconv"
	"testing"

	"github.com/ohMySol/eigen-auction/avs/internal/chaincfg"
	"github.com/ohMySol/eigen-auction/avs/internal/consensus"
	"github.com/ohMySol/eigen-auction/avs/internal/feed"
)

func env(t *testing.T) (rpc, dir string, chainID uint64) {
	t.Helper()
	dir = os.Getenv("DEPLOYMENTS_DIR")
	cidStr := os.Getenv("CHAIN_ID")
	if dir == "" || cidStr == "" {
		t.Skip("set DEPLOYMENTS_DIR and CHAIN_ID (and run against a fork) to exercise the Tier-2 harness")
	}
	cid, err := strconv.ParseUint(cidStr, 10, 64)
	if err != nil {
		t.Fatalf("bad CHAIN_ID: %v", err)
	}
	rpc = os.Getenv("RPC_URL")
	if rpc == "" {
		rpc = "http://localhost:8545"
	}
	return rpc, dir, cid
}

// The golden-vector batch (same inputs as the unit tests) so on-chain == Go == golden all at once.
func goldenBatch() (consensus.ToBOrder, *big.Int, []consensus.IntentTerms) {
	var poolID [32]byte
	for i := range poolID {
		poolID[i] = 0x11
	}
	addr := func(b byte) [20]byte { var a [20]byte; a[19] = b; return a }
	arb := consensus.ToBOrder{
		Searcher: addr(0xa1), PoolID: poolID, ZeroForOne: true, UseInternal: false,
		QuantityIn: big.NewInt(1_050_000_000_000_000_000), QuantityOut: big.NewInt(1_000_000_000_000_000_000),
		ValidForBlock: big.NewInt(100),
	}
	intents := []consensus.IntentTerms{
		{User: addr(0xb1), PoolID: poolID, ZeroForOne: false, UseInternal: true,
			AmountIn: big.NewInt(5_000_000_000_000_000_000), MinAmountOut: big.NewInt(4_900_000_000_000_000_000),
			Nonce: big.NewInt(7), Deadline: big.NewInt(1_000_000)},
		{User: addr(0xb2), PoolID: poolID, ZeroForOne: true, UseInternal: false,
			AmountIn: big.NewInt(2_000_000_000_000_000_000), MinAmountOut: big.NewInt(1_900_000_000_000_000_000),
			Nonce: big.NewInt(8), Deadline: big.NewInt(2_000_000)},
	}
	return arb, new(big.Int).Lsh(big.NewInt(2000), 128), intents
}

func TestComputeResultHashMatchesDeployedSettler(t *testing.T) {
	rpc, dir, chainID := env(t)
	dep, err := chaincfg.Load(dir, chainID)
	if err != nil {
		t.Fatalf("load deployment: %v", err)
	}
	ctx := context.Background()
	c, err := Dial(ctx, rpc, dep.Settler, dep.TaskManager)
	if err != nil {
		t.Fatalf("dial %s: %v", rpc, err)
	}

	arb, price, intents := goldenBatch()
	signed := make([]feed.SignedIntent, len(intents))
	for i, it := range intents {
		signed[i] = feed.SignedIntent{Intent: it}
	}

	onchain, err := c.Settler.ComputeResultHash(nil, SettlerOrder(arb, nil), price, SettlerIntents(signed))
	if err != nil {
		t.Fatalf("computeResultHash call: %v", err)
	}
	local := consensus.Compute(arb, price, intents)
	if onchain != local {
		t.Fatalf("resultHash mismatch:\n on-chain %x\n go       %x", onchain, local)
	}
	if got := hex.EncodeToString(local[:]); got != "e7c8f352536e6767c8d9e173dbaa5ed772196e83f2b75dc76e084629119a3f80" {
		t.Fatalf("golden drift: %s", got)
	}

	// Domain separator: our EIP-712 domain must equal the deployed Settler's.
	onDomain, err := c.Settler.DOMAINSEPARATOR(nil)
	if err != nil {
		t.Fatalf("DOMAIN_SEPARATOR call: %v", err)
	}
	goDomain := consensus.DomainSeparator(dep.Settler, new(big.Int).SetUint64(chainID))
	if onDomain != goDomain {
		t.Fatalf("domain separator mismatch:\n on-chain %x\n go       %x", onDomain, goDomain)
	}
}
