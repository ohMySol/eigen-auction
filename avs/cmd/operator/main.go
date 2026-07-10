// Command operator is one AVS operator node. Per target block it fetches the relay's sealed set,
// runs the deterministic core (node.Operator.RunBlock → operator.Resolve), BLS-signs the msgHash, and
// submits to the aggregator; if it is the drawn executor it settles once the commit lands. Run N of
// these with N key sets for a multi-operator quorum. The consensus logic is all in internal/*; this
// file is only wiring, so it is build-checked, not unit-tested (the loop is exercised on the fork).
package main

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/Layr-Labs/eigensdk-go/crypto/bls"
	eigentypes "github.com/Layr-Labs/eigensdk-go/types"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"

	"github.com/ohMySol/eigen-auction/avs/internal/attest"
	"github.com/ohMySol/eigen-auction/avs/internal/chain"
	"github.com/ohMySol/eigen-auction/avs/internal/chaincfg"
	"github.com/ohMySol/eigen-auction/avs/internal/consensus"
	"github.com/ohMySol/eigen-auction/avs/internal/feed"
	"github.com/ohMySol/eigen-auction/avs/internal/node"
	"github.com/ohMySol/eigen-auction/avs/internal/operator"
)

// commit + settle must both execute in the target block (both are keyed to block.number on-chain), so
// the operator targets head+1 and submits its settle OPTIMISTICALLY into that pending block alongside
// the aggregator's commit. The drive-round script (manual mining) then mines exactly that one block.
// On mainnet this same-block pairing is a Flashbots bundle; this is its anvil equivalent.
const targetOffset = 1

// Fee caps for the fork. The settle tip is deliberately lower than the aggregator's commit tip so that,
// within the shared target block, anvil (fee-ordered) executes commitWinner before settle — settle
// reads the commitment commit just wrote. GasFeeCap is set high enough to clear a mainnet-fork base fee.
var (
	settleTip = big.NewInt(1_000_000_000)   // 1 gwei
	feeCap = big.NewInt(200_000_000_000) // 200 gwei
)

func main() {
	log.SetFlags(log.Ltime)
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	chainID := mustUint("CHAIN_ID")
	dep, err := chaincfg.Load(os.Getenv("DEPLOYMENTS_DIR"), chainID)
	must(err, "load deployment")

	cl, err := chain.Dial(ctx, mustEnv("RPC_URL"), dep.Settler, dep.TaskManager)
	must(err, "dial chain")

	keys, err := bls.NewKeyPairFromString(mustEnv("BLS_PRIVATE_KEY"))
	must(err, "load BLS key")
	// operatorId = keccak256(U256(pubkeyG1.X) || U256(pubkeyG1.Y)), matching BLSApkRegistry.getOperatorId,
	// so the id this operator submits is the one blsagg keys it by in the registry state.
	operatorID := common.Hash(eigentypes.OperatorIdFromKeyPair(keys))

	settleKey, err := crypto.HexToECDSA(strings.TrimPrefix(mustEnv("OPERATOR_PK"), "0x"))
	must(err, "load settle key")
	settleAddr := crypto.PubkeyToAddress(settleKey.PublicKey)

	op := &node.Operator{
		PoolID: dep.Pool.PoolID,
		Settler: dep.Settler,
		ChainID: new(big.Int).SetUint64(chainID),
		OperatorID: operatorID,
		Keys: keys,
		Feed: feed.NewClient(mustEnv("FEED_URL")),
		Chain: cl,
		Quorum: buildQuorum(dep, mustEnv("RPC_URL"), operatorID, [20]byte(settleAddr)),
		Submitter: httpSubmitter{url: mustEnv("AGGREGATOR_URL"), c: &http.Client{Timeout: 3 * time.Second}},
	}
	log.Printf("operator up: id=%s settle=%s pool=%s", operatorID.Hex(), settleAddr.Hex(), dep.Pool.PoolID.Hex())

	runLoop(ctx, cl, op, dep, settleKey, [20]byte(settleAddr))
}

// runLoop continuously prepares the next target block (head+1). It polls the relay each tick: an empty
// sealed set is skipped (retried next tick until a batch is posted), a non-empty one is signed and
// submitted once, and if this operator is the drawn executor it submits its settle optimistically into
// the same pending block. The drive-round script mines that block once both commit and settle are queued.
func runLoop(ctx context.Context, cl *chain.Client, op *node.Operator, dep *chaincfg.Deployment, settleKey *ecdsa.PrivateKey, settleAddr [20]byte) {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	submitted := map[uint64]bool{}
	for {
		select {
		case <-ctx.Done():
			log.Println("operator shutting down")
			return
		case <-ticker.C:
		}
		head, err := cl.BlockNumber(ctx)
		if err != nil {
			continue
		}
		target := head + targetOffset
		if submitted[target] {
			continue
		}

		set, res, ok, err := op.RunBlock(ctx, target)
		if err != nil {
			log.Printf("block %d: %v", target, err)
			continue
		}
		if !ok {
			continue // nothing sealed for this block yet; keep polling
		}
		submitted[target] = true
		for t := range submitted { // prune old targets so the map stays bounded
			if t+8 < target {
				delete(submitted, t)
			}
		}
		log.Printf("block %d: signed msgHash=%s executor=%s hasArb=%v",
			target, common.Hash(res.MsgHash).Hex(), common.Address(res.Executor).Hex(), res.HasArb)

		if op.IsExecutor(res, settleAddr) && (res.HasArb || len(set.Intents) > 0) {
			go settleWhenCommitPending(ctx, cl, op, dep, set, res, settleKey, target)
		}
	}
}

// settleWhenCommitPending waits until the aggregator's commitWinner is queued for this block — visible
// in the *pending* state — then submits settle into that same pending block. Gating on a pending commit
// means the operator only ever settles when there is actually a commit to pair with, so a standalone
// operator (no round orchestrating) never spams reverting settles. Runs in its own goroutine so the
// poll loop keeps preparing later blocks.
func settleWhenCommitPending(ctx context.Context, cl *chain.Client, op *node.Operator, dep *chaincfg.Deployment, set *feed.SealedSet, res operator.Result, settleKey *ecdsa.PrivateKey, target uint64) {
	for i := 0; i < 40; i++ {
		c, err := cl.TaskManager.GetCommitment(&bind.CallOpts{Context: ctx, Pending: true}, dep.Pool.PoolID, new(big.Int).SetUint64(target))
		if err == nil && c.Exists {
			auth, err := bind.NewKeyedTransactorWithChainID(settleKey, op.ChainID)
			if err != nil {
				log.Printf("block %d: settle auth: %v", target, err)
				return
			}
			auth.GasTipCap, auth.GasFeeCap = settleTip, feeCap
			// Fixed gas limit skips eth_estimateGas: settle still reverts in isolation (the commit
			// executes first, in the same block), so estimation would abort the send. A set limit lets
			// settle queue as pending for drive-round to mine right after commitWinner.
			auth.GasLimit = 8_000_000
			tx, err := op.Settle(auth, cl, dep, set, res)
			if err != nil {
				log.Printf("block %d: settle submit: %v", target, err)
				return
			}
			log.Printf("block %d: settle submitted tx=%s", target, tx.Hash().Hex())
			return
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(500 * time.Millisecond):
		}
	}
	// No commit appeared for this block — nothing is orchestrating a round, so stay quiet.
}

// --- wiring helpers ---

// buildQuorum selects the operator-set membership the executor draw ranks over. Default: the
// chain-backed reader over OperatorStateRetriever, so N registered operators all draw over the same
// on-chain set. Set STATIC_QUORUM=1 to fall back to a single-operator quorum (this node only) for
// infra-free dev where no registry is deployed.
func buildQuorum(dep *chaincfg.Deployment, rpcURL string, operatorID [32]byte, settleAddr [20]byte) node.Quorum {
	if os.Getenv("STATIC_QUORUM") == "1" {
		log.Println("STATIC_QUORUM=1: single-operator quorum (no registry read)")
		return staticQuorum{[]consensus.Operator{{ID: operatorID, Addr: settleAddr}}}
	}
	q, err := chain.NewQuorumReader(rpcURL, dep.RegistryCoordinator, dep.OperatorStateRetriever, dep.QuorumNumbers)
	must(err, "build quorum reader")
	return q
}

type staticQuorum struct{ ops []consensus.Operator }

func (s staticQuorum) QuorumZero(context.Context, uint64) ([]consensus.Operator, error) {
	return s.ops, nil
}

type httpSubmitter struct {
	url string
	c *http.Client
}

func (h httpSubmitter) Submit(ctx context.Context, r attest.SignedResponse) error {
	body, err := json.Marshal(r)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, h.url+"/submit", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := h.c.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode/100 != 2 {
		return fmt.Errorf("aggregator status %d", resp.StatusCode)
	}
	return nil
}

func mustEnv(k string) string {
	v := os.Getenv(k)
	if v == "" {
		log.Fatalf("env %s is required", k)
	}
	return v
}

func mustUint(k string) uint64 {
	v, err := strconv.ParseUint(mustEnv(k), 10, 64)
	must(err, "parse "+k)
	return v
}

func must(err error, ctx string) {
	if err != nil {
		log.Fatalf("%s: %v", ctx, err)
	}
}
