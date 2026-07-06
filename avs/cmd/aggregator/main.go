// Command aggregator is the AVS's dumb relay. It receives operators' SignedResponses, feeds them into
// eigensdk's blsagg service (which tracks signed stake against the registry snapshot at the reference
// block), and once quorum stake has signed, builds the NonSignerStakesAndSignature and submits
// commitWinner. It holds no BLS key and makes no auction decisions — the quorum forms only around a
// result a threshold of staked operators independently computed. This file is fork-gated wiring; the
// verified pieces (NSS mapping, round tracking) live in internal/agg with tests.
package main

import (
	"context"
	"encoding/json"
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
	"github.com/Layr-Labs/eigensdk-go/logging"
	avsregistrychain "github.com/Layr-Labs/eigensdk-go/chainio/clients/avsregistry"
	"github.com/Layr-Labs/eigensdk-go/services/avsregistry"
	"github.com/Layr-Labs/eigensdk-go/services/operatorsinfo"
	blsagg "github.com/Layr-Labs/eigensdk-go/services/bls_aggregation"
	"github.com/Layr-Labs/eigensdk-go/types"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"

	"github.com/ohMySol/eigen-auction/avs/internal/agg"
	"github.com/ohMySol/eigen-auction/avs/internal/attest"
	"github.com/ohMySol/eigen-auction/avs/internal/chain"
	"github.com/ohMySol/eigen-auction/avs/internal/chaincfg"
)

// The deployed operator set is quorum 0 only; the signed stake must reach this fraction to commit.
var quorumNumbers = types.QuorumNums{0}
var quorumThresholds = types.QuorumThresholdPercentages{67}

const taskTimeout = 12 * time.Second // the auction window: how long to collect signatures per block

func main() {
	log.SetFlags(log.Ltime)
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	chainID := mustUint("CHAIN_ID")
	dep, err := chaincfg.Load(os.Getenv("DEPLOYMENTS_DIR"), chainID)
	must(err, "load deployment")

	cl, err := chain.Dial(ctx, mustEnv("RPC_URL"), dep.Settler, dep.TaskManager)
	must(err, "dial chain")

	commitKey, err := crypto.HexToECDSA(strings.TrimPrefix(mustEnv("AGGREGATOR_PK"), "0x"))
	must(err, "load aggregator key")
	auth, err := bind.NewKeyedTransactorWithChainID(commitKey, new(big.Int).SetUint64(chainID))
	must(err, "build transactor")

	blsService := buildBlsAggService(ctx, dep, mustEnv("RPC_URL"), mustEnv("WS_URL"))
	rounds := agg.NewRounds()

	// Reader: on each aggregation, build the NSS and commit.
	go commitLoop(ctx, blsService, rounds, cl, auth)

	mux := http.NewServeMux()
	mux.HandleFunc("/submit", submitHandler(ctx, blsService, rounds))
	srv := &http.Server{Addr: mustEnv("LISTEN_ADDR"), Handler: mux}
	go func() {
		<-ctx.Done()
		_ = srv.Shutdown(context.Background())
	}()
	log.Printf("aggregator listening on %s", srv.Addr)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("http: %v", err)
	}
}

// submitHandler ingests one operator SignedResponse: it opens the blsagg task on first sight of a
// (poolId, targetBlock) round, then feeds the signature in.
func submitHandler(ctx context.Context, svc *blsagg.BlsAggregatorService, rounds *agg.Rounds) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var sr attest.SignedResponse
		if err := json.NewDecoder(r.Body).Decode(&sr); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		idx, isNew := rounds.Track(sr)
		if isNew {
			meta := blsagg.NewTaskMetadata(idx, sr.ReferenceBlockNumber, quorumNumbers, quorumThresholds, taskTimeout)
			if err := svc.InitializeNewTask(meta); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
		}
		sig := &bls.Signature{G1Point: bls.NewZeroG1Point().Deserialize(sr.SigG1)}
		task := blsagg.NewTaskSignature(idx, [32]byte(sr.MsgHash), sig, types.OperatorId(sr.OperatorID))
		if err := svc.ProcessNewSignature(ctx, task); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusAccepted)
	}
}

func commitLoop(ctx context.Context, svc *blsagg.BlsAggregatorService, rounds *agg.Rounds, cl *chain.Client, auth *bind.TransactOpts) {
	for {
		select {
		case <-ctx.Done():
			return
		case resp := <-svc.GetResponseChannel():
			if resp.Err != nil {
				log.Printf("aggregation error: %v", resp.Err)
				continue
			}
			rd, ok := rounds.Get(resp.TaskIndex)
			if !ok {
				log.Printf("aggregation for unknown task %d", resp.TaskIndex)
				continue
			}
			nss := agg.NonSignerStakesAndSignature(resp)
			tx, err := cl.TaskManager.CommitWinner(auth, rd.PoolID, new(big.Int).SetUint64(rd.TargetBlock),
				rd.ResultHash, rd.Executor, rd.ReferenceBlock, quorumBytes(), nss)
			if err != nil {
				log.Printf("block %d: commitWinner: %v", rd.TargetBlock, err)
				continue
			}
			log.Printf("block %d: committed executor=%s tx=%s", rd.TargetBlock, common.Address(rd.Executor).Hex(), tx.Hash().Hex())
		}
	}
}

// buildBlsAggService wires the eigensdk stack: registry reader + websocket subscriber → in-memory
// operator-info service → chain-caller AVS registry service → blsagg. This is the fork seam — it only
// does anything real against a chain with a registered operator set.
func buildBlsAggService(ctx context.Context, dep *chaincfg.Deployment, rpcURL, wsURL string) *blsagg.BlsAggregatorService {
	logger := logging.NewTextSLogger(os.Stdout, &logging.SLoggerOptions{})

	httpClient, err := ethclient.Dial(rpcURL)
	must(err, "dial http eth client")
	wsClient, err := ethclient.Dial(wsURL)
	must(err, "dial ws eth client")

	cfg := avsregistrychain.Config{
		RegistryCoordinatorAddress: dep.RegistryCoordinator,
		OperatorStateRetrieverAddress: dep.OperatorStateRetriever,
	}
	reader, err := avsregistrychain.NewReaderFromConfig(cfg, httpClient, logger)
	must(err, "build registry reader")
	subscriber, err := avsregistrychain.NewSubscriberFromConfig(cfg, wsClient, logger)
	must(err, "build registry subscriber")

	opsInfo := operatorsinfo.NewOperatorsInfoServiceInMemory(ctx, subscriber, reader, nil, operatorsinfo.Opts{}, logger)
	avsReg := avsregistry.NewAvsRegistryServiceChainCaller(reader, opsInfo, logger)

	// Operators signed msgHash directly, so the task-response digest IS the msgHash.
	hashFn := func(tr types.TaskResponse) (types.TaskResponseDigest, error) {
		return types.TaskResponseDigest(tr.([32]byte)), nil
	}
	return blsagg.NewBlsAggregatorService(avsReg, hashFn, logger)
}

func quorumBytes() []byte {
	b := make([]byte, len(quorumNumbers))
	for i, q := range quorumNumbers {
		b[i] = byte(q)
	}
	return b
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
