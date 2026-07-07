// Command register onboards one operator into the AVS operator set (§4.5) — the gate to running the
// BLS flow. It is run once per operator with that operator's ECDSA + BLS keys, against the mainnet
// fork after `make deploy-fork`. The steps use eigensdk's ElChainWriter, which computes the BLS
// pubkey-registration proof internally:
//
//  1. RegisterAsOperator            — become an EigenLayer operator (skipped if already one).
//  2. (optional) deposit + allocate — give the operator slashable weight in the quorum's strategy.
//  3. RegisterForOperatorSets       — join the operator set so the BLS pubkey lands in BLSApkRegistry.
//
// Fork-gated: build-checked here, exercised on the fork. Fund the operator's stake token via anvil
// cheats (like `make fund`) before running with STAKE_AMOUNT set.
package main

import (
	"context"
	"log"
	"math/big"
	"os"
	"strconv"
	"strings"

	"github.com/Layr-Labs/eigensdk-go/chainio/clients"
	"github.com/Layr-Labs/eigensdk-go/chainio/clients/elcontracts"
	almbind "github.com/Layr-Labs/eigensdk-go/contracts/bindings/AllocationManager"
	"github.com/Layr-Labs/eigensdk-go/crypto/bls"
	"github.com/Layr-Labs/eigensdk-go/logging"
	eigentypes "github.com/Layr-Labs/eigensdk-go/types"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"

	"github.com/ohMySol/eigen-auction/avs/internal/chaincfg"
)

func main() {
	log.SetFlags(log.Ltime)
	ctx := context.Background()

	chainID := mustUint("CHAIN_ID")
	dep, err := chaincfg.Load(os.Getenv("DEPLOYMENTS_DIR"), chainID)
	must(err, "load deployment")

	ecdsaKey, err := crypto.HexToECDSA(strings.TrimPrefix(mustEnv("OPERATOR_PK"), "0x"))
	must(err, "load operator ECDSA key")
	operatorAddr := crypto.PubkeyToAddress(ecdsaKey.PublicKey)

	blsKeys, err := bls.NewKeyPairFromString(mustEnv("BLS_PRIVATE_KEY"))
	must(err, "load operator BLS key")

	logger := logging.NewTextSLogger(os.Stdout, &logging.SLoggerOptions{})
	cl, err := clients.BuildAll(clients.BuildAllConfig{
		EthHttpUrl: mustEnv("RPC_URL"),
		EthWsUrl: mustEnv("WS_URL"),
		AvsName: "eigen-auction",
		PromMetricsIpPortAddress: envOr("METRICS_ADDR", ":9091"),
		RegistryCoordinatorAddr: dep.RegistryCoordinator.Hex(),
		OperatorStateRetrieverAddr: dep.OperatorStateRetriever.Hex(),
		RewardsCoordinatorAddress: mustEnv("REWARDS_COORDINATOR"),
		PermissionControllerAddress: mustEnv("PERMISSION_CONTROLLER"),
	}, ecdsaKey, logger)
	must(err, "build eigensdk clients")
	el := cl.ElChainWriter
	setID := uint32(dep.QuorumNumbers)

	// 1. Become an EigenLayer operator. On the mainnet fork the deployer-operator may already be one;
	// log and continue rather than abort so re-running is safe.
	if _, err := el.RegisterAsOperator(ctx, eigentypes.Operator{
		Address: operatorAddr.Hex(),
		MetadataUrl: "https://eigen-auction.local/operator.json",
	}, true); err != nil {
		log.Printf("registerAsOperator (continuing, may already be registered): %v", err)
	}

	// 2. Optional stake: deposit into the quorum's strategy and allocate magnitude to the operator set.
	// With MIN_OPERATOR_STAKE=0 an operator can join with none, but real signed-stake accounting needs it.
	if amt := os.Getenv("STAKE_AMOUNT"); amt != "" {
		amount, ok := new(big.Int).SetString(amt, 10)
		if !ok {
			log.Fatalf("STAKE_AMOUNT %q is not a base-10 integer", amt)
		}
		if _, err := el.DepositERC20IntoStrategy(ctx, dep.StakeStrategy, amount, true); err != nil {
			log.Fatalf("deposit into strategy: %v", err)
		}
		if _, err := el.ModifyAllocations(ctx, operatorAddr, []almbind.IAllocationManagerTypesAllocateParams{{
			OperatorSet: almbind.OperatorSet{Avs: dep.ServiceManager, Id: setID},
			Strategies: []common.Address{dep.StakeStrategy},
			NewMagnitudes: []uint64{mustUint64("STAKE_MAGNITUDE")},
		}}, true); err != nil {
			log.Fatalf("modify allocations: %v", err)
		}
		log.Printf("staked: deposited %s, allocated to operator set %d", amount, setID)
	}

	// 3. Register into the operator set — routes through the coordinator so the BLS pubkey lands in
	// BLSApkRegistry. eigensdk computes the pubkey-registration proof from the BLS keypair.
	if _, err := el.RegisterForOperatorSets(ctx, dep.RegistryCoordinator, elcontracts.RegistrationRequest{
		OperatorAddress: operatorAddr,
		AVSAddress: dep.ServiceManager,
		OperatorSetIds: []uint32{setID},
		BlsKeyPair: blsKeys,
		Socket: "https://eigen-auction.local/operator",
		WaitForReceipt: true,
	}); err != nil {
		log.Fatalf("registerForOperatorSets: %v", err)
	}

	operatorID := crypto.Keccak256Hash(blsKeys.GetPubKeyG1().Serialize())
	log.Printf("registered operator %s into set %d (operatorId=%s)", operatorAddr.Hex(), setID, operatorID.Hex())
}

func mustEnv(k string) string {
	v := os.Getenv(k)
	if v == "" {
		log.Fatalf("env %s is required", k)
	}
	return v
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func mustUint(k string) uint64 {
	v, err := strconv.ParseUint(mustEnv(k), 10, 64)
	must(err, "parse "+k)
	return v
}

func mustUint64(k string) uint64 {
	v, err := strconv.ParseUint(mustEnv(k), 10, 64)
	must(err, "parse "+k)
	return v
}

func must(err error, ctx string) {
	if err != nil {
		log.Fatalf("%s: %v", ctx, err)
	}
}
