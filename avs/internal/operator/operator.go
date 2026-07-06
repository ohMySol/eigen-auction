// Package operator holds the operator's per-block logic. Resolve is the deterministic heart: from the
// relay-sealed set plus the on-chain prevrandao it produces the exact msgHash every honest operator
// BLS-signs. It composes the whole consensus pipeline (verify → elect → resultHash → draw → msgHash),
// so it is fully unit-testable without a chain or the aggregator — the fork-gated parts (BLS signing,
// submit, settle) are the thin shell in cmd/operator around this.
package operator

import (
	"math/big"

	"github.com/ohMySol/eigen-auction/avs/internal/chain"
	"github.com/ohMySol/eigen-auction/avs/internal/consensus"
	"github.com/ohMySol/eigen-auction/avs/internal/feed"
)

// Result is everything the block resolves to: the winning arb (with its searcher signature, needed
// to settle), the committed resultHash, the drawn executor, and the msgHash to sign.
type Result struct {
	Arb consensus.ToBOrder
	ArbSig []byte
	HasArb bool
	ResultHash [32]byte
	Executor [20]byte
	MsgHash [32]byte
}

// Resolve runs the full deterministic computation for one target block. `operators` must be quorum 0
// sorted by ID (the draw's canonical order); prevrandao is read from chain at set.ReferenceBlockNumber.
func Resolve(set *feed.SealedSet, poolID [32]byte, prevrandao [32]byte, operators []consensus.Operator, settler [20]byte, chainID *big.Int) Result {
	targetBlock := new(big.Int).SetUint64(set.TargetBlock)

	// Keep only orders with a valid searcher signature — the Settler rejects an unsigned arb on settle
	// (Settler_InvalidArbSignature), so an invalid-sig order must never win the auction.
	var valid []consensus.ToBOrder
	sigByHash := make(map[[32]byte][]byte, len(set.Orders))
	for _, so := range set.Orders {
		signer, err := chain.RecoverToBOrderSigner(so.Order, so.Signature, settler, chainID)
		if err != nil || signer != so.Order.Searcher {
			continue
		}
		valid = append(valid, so.Order)
		sigByHash[consensus.ToBStructHash(so.Order)] = so.Signature
	}

	arb, hasArb := consensus.ElectWinner(valid, set.ClearingPriceX128)
	var arbSig []byte
	if hasArb {
		arbSig = sigByHash[consensus.ToBStructHash(arb)]
	} else {
		// No winner: hash an all-zero arb, which computeResultHash treats as "no arb this block".
		arb = consensus.ToBOrder{QuantityIn: big.NewInt(0), QuantityOut: big.NewInt(0)}
	}

	terms := make([]consensus.IntentTerms, len(set.Intents))
	for i, si := range set.Intents {
		terms[i] = si.Intent
	}

	resultHash := consensus.Compute(arb, set.ClearingPriceX128, terms)
	executor := consensus.Executor(operators, poolID, targetBlock, resultHash, prevrandao)
	msgHash := consensus.MsgHash(poolID, targetBlock, resultHash, executor)

	return Result{Arb: arb, ArbSig: arbSig, HasArb: hasArb, ResultHash: resultHash, Executor: executor, MsgHash: msgHash}
}
