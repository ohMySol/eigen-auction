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

// On anvil automine, commitWinner mines its own block before settle, so settle lands at head+offset —
// the block its winner is committed for. Precise same-block landing on a live chain needs top-of-block
// submission (a later milestone); this offset is the fork assumption, mirroring the TS harness.
const settleBlockOffset = 2

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
	operatorID := crypto.Keccak256Hash(keys.GetPubKeyG1().Serialize())

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
		// Single-operator dev quorum: this node is the whole quorum-0. The chain-backed registry
		// provider (OperatorStateRetriever) replaces this when scaling to N operators.
		Quorum: staticQuorum{[]consensus.Operator{{ID: operatorID, Addr: [20]byte(settleAddr)}}},
		Submitter: httpSubmitter{url: mustEnv("AGGREGATOR_URL"), c: &http.Client{Timeout: 3 * time.Second}},
	}
	log.Printf("operator up: id=%s settle=%s pool=%s", operatorID.Hex(), settleAddr.Hex(), dep.Pool.PoolID.Hex())

	runLoop(ctx, cl, op, dep, settleKey, [20]byte(settleAddr))
}

func runLoop(ctx context.Context, cl *chain.Client, op *node.Operator, dep *chaincfg.Deployment, settleKey *ecdsa.PrivateKey, settleAddr [20]byte) {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	var last uint64
	for {
		select {
		case <-ctx.Done():
			log.Println("operator shutting down")
			return
		case <-ticker.C:
		}
		head, err := cl.BlockNumber(ctx)
		if err != nil || head == last {
			continue
		}
		last = head
		target := head + settleBlockOffset

		set, res, err := op.RunBlock(ctx, target)
		if err != nil {
			log.Printf("block %d: %v", target, err)
			continue
		}
		log.Printf("block %d: signed msgHash=%s executor=%s hasArb=%v",
			target, common.Hash(res.MsgHash).Hex(), common.Address(res.Executor).Hex(), res.HasArb)

		if op.IsExecutor(res, settleAddr) && (res.HasArb || len(set.Intents) > 0) {
			auth, err := bind.NewKeyedTransactorWithChainID(settleKey, op.ChainID)
			if err != nil {
				log.Printf("block %d: auth: %v", target, err)
				continue
			}
			settleWhenCommitted(ctx, cl, op, dep, set, res, auth, target)
		}
	}
}

// settleWhenCommitted waits for the aggregator's commit to land, then settles as the drawn executor.
func settleWhenCommitted(ctx context.Context, cl *chain.Client, op *node.Operator, dep *chaincfg.Deployment, set *feed.SealedSet, res operator.Result, auth *bind.TransactOpts, target uint64) {
	for i := 0; i < 30; i++ {
		c, err := cl.TaskManager.GetCommitment(&bind.CallOpts{Context: ctx}, dep.Pool.PoolID, new(big.Int).SetUint64(target))
		if err == nil && c.Exists {
			tx, err := op.Settle(auth, cl, dep, set, res)
			if err != nil {
				log.Printf("block %d: settle: %v", target, err)
				return
			}
			log.Printf("block %d: settled tx=%s", target, tx.Hash().Hex())
			return
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(500 * time.Millisecond):
		}
	}
	log.Printf("block %d: commit never landed; skipping settle", target)
}

// --- wiring helpers ---

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
