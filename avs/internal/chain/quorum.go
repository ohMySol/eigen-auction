package chain

import (
	"bytes"
	"context"
	"io"
	"sort"

	avsregistry "github.com/Layr-Labs/eigensdk-go/chainio/clients/avsregistry"
	"github.com/Layr-Labs/eigensdk-go/logging"
	eigentypes "github.com/Layr-Labs/eigensdk-go/types"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"

	"github.com/ohMySol/eigen-auction/avs/internal/consensus"
)

// QuorumReader resolves quorum-0's registered operators from the on-chain registry at a reference
// block — the chain-backed membership the executor draw ranks over, replacing the dev harness's static
// single-operator quorum. It reads OperatorStateRetriever, which returns each operator's registry id
// and (EL operator = settle) address. The set is snapshotted at referenceBlockNumber — the same block
// the aggregator's stake snapshot uses — so with N registered operators every node reads the identical
// set and independently draws the identical executor.
type QuorumReader struct {
	reader *avsregistry.ChainReader
	quorum eigentypes.QuorumNums
}

// NewQuorumReader builds the registry reader from the deployment's RegistryCoordinator +
// OperatorStateRetriever. quorumID is the operator-set id operators register against (dep.QuorumNumbers),
// read from the deployment so it always matches what operators sign and register against.
func NewQuorumReader(rpcURL string, registryCoordinator, operatorStateRetriever common.Address, quorumID uint8) (*QuorumReader, error) {
	eth, err := ethclient.Dial(rpcURL)
	if err != nil {
		return nil, err
	}
	cfg := avsregistry.Config{
		RegistryCoordinatorAddress: registryCoordinator,
		OperatorStateRetrieverAddress: operatorStateRetriever,
	}
	// The reader only makes read calls; silence its logger (registry wiring is logged by the caller).
	reader, err := avsregistry.NewReaderFromConfig(cfg, eth, logging.NewTextSLogger(io.Discard, nil))
	if err != nil {
		return nil, err
	}
	return &QuorumReader{reader: reader, quorum: eigentypes.QuorumNums{eigentypes.QuorumNum(quorumID)}}, nil
}

// QuorumZero returns quorum-0's members at refBlock, sorted by operator id ascending — the canonical
// order the draw requires so every operator ranks the set identically (the draw is off-chain: nodes
// refuse to sign a msgHash whose executor differs from their own computation over this order). The
// retriever already yields operators in increasing-id order; the explicit sort makes the draw invariant
// independent of that and is cheap for the small quorums here.
func (q *QuorumReader) QuorumZero(ctx context.Context, refBlock uint64) ([]consensus.Operator, error) {
	states, err := q.reader.GetOperatorsStakeInQuorumsAtBlock(&bind.CallOpts{Context: ctx}, q.quorum, uint32(refBlock))
	if err != nil {
		return nil, err
	}
	if len(states) == 0 {
		return nil, nil
	}
	ops := make([]consensus.Operator, 0, len(states[0]))
	for _, o := range states[0] {
		ops = append(ops, consensus.Operator{ID: o.OperatorId, Addr: [20]byte(o.Operator)})
	}
	sort.Slice(ops, func(i, j int) bool { return bytes.Compare(ops[i].ID[:], ops[j].ID[:]) < 0 })
	return ops, nil
}
