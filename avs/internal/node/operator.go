// Package node orchestrates the operator's per-block work around the pure core: fetch the sealed set,
// read prevrandao + the quorum, run operator.Resolve, BLS-sign, and submit to the aggregator. The IO
// edges are interfaces so the real feed/chain clients plug in for the fork while a test drives the
// whole flow with fakes and a real BLS key — keeping the loop unit-testable, not just build-checked.
package node

import (
	"context"
	"math/big"

	"github.com/Layr-Labs/eigensdk-go/crypto/bls"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/ohMySol/eigen-auction/avs/internal/attest"
	"github.com/ohMySol/eigen-auction/avs/internal/chain"
	"github.com/ohMySol/eigen-auction/avs/internal/chaincfg"
	"github.com/ohMySol/eigen-auction/avs/internal/consensus"
	"github.com/ohMySol/eigen-auction/avs/internal/feed"
	"github.com/ohMySol/eigen-auction/avs/internal/operator"
)

type SealedFeed interface {
	Fetch(ctx context.Context, block uint64) (*feed.SealedSet, error)
}

type Randao interface {
	Prevrandao(ctx context.Context, block uint64) ([32]byte, error)
}

// Quorum returns quorum-0 operators sorted by ID at a reference block — the canonical order the
// executor draw depends on (§2.6). Backed by the registry on the fork; static in the dev harness.
type Quorum interface {
	QuorumZero(ctx context.Context, refBlock uint64) ([]consensus.Operator, error)
}

type Submitter interface {
	Submit(ctx context.Context, r attest.SignedResponse) error
}

// Operator wires the pure core to its IO edges. Identity is (Keys, OperatorID); PoolID/Settler/ChainID
// come from the deployment.
type Operator struct {
	PoolID [32]byte
	Settler [20]byte
	ChainID *big.Int
	OperatorID [32]byte
	Keys *bls.KeyPair
	Feed SealedFeed
	Chain Randao
	Quorum Quorum
	Submitter Submitter
}

// RunBlock resolves one target block, BLS-signs the msgHash, and submits the response. It returns the
// sealed set and Result so the caller can settle when this operator is the drawn executor (the set
// carries the intents + clearing price settle needs).
func (o *Operator) RunBlock(ctx context.Context, targetBlock uint64) (*feed.SealedSet, operator.Result, error) {
	set, err := o.Feed.Fetch(ctx, targetBlock)
	if err != nil {
		return nil, operator.Result{}, err
	}
	seed, err := o.Chain.Prevrandao(ctx, uint64(set.ReferenceBlockNumber))
	if err != nil {
		return nil, operator.Result{}, err
	}
	ops, err := o.Quorum.QuorumZero(ctx, uint64(set.ReferenceBlockNumber))
	if err != nil {
		return nil, operator.Result{}, err
	}

	res := operator.Resolve(set, o.PoolID, seed, ops, o.Settler, o.ChainID)
	sig := o.Keys.SignMessage(res.MsgHash)
	sr := attest.Build(res, o.PoolID, targetBlock, set.ReferenceBlockNumber, o.OperatorID, sig)
	if err := o.Submitter.Submit(ctx, sr); err != nil {
		return set, res, err
	}
	return set, res, nil
}

// IsExecutor reports whether this operator was drawn to settle the block.
func (o *Operator) IsExecutor(res operator.Result, settleAddr [20]byte) bool {
	return res.Executor == settleAddr
}

// Settle submits the block on the Settler as the drawn executor: it re-derives the same batch the
// quorum committed (arb + intents + clearing price via the tested mappers), so the Settler's
// computeResultHash matches the commitment. Call only after the aggregator's commitWinner has landed.
func (o *Operator) Settle(auth *bind.TransactOpts, cl *chain.Client, dep *chaincfg.Deployment, set *feed.SealedSet, res operator.Result) (*types.Transaction, error) {
	return cl.Settler.Settle(auth, chain.PoolKey(dep), chain.SettlerOrder(res.Arb, res.ArbSig), chain.SettlerIntents(set.Intents), set.ClearingPriceX128)
}
