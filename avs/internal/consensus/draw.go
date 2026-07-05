package consensus

import "math/big"

// Operator is a quorum-0 member: its registry ID and the address that settles if drawn.
type Operator struct {
	ID [32]byte
	Addr [20]byte
}

// Executor deterministically draws the settling operator for a block (§2.6). Because the draw is a
// pure function of public inputs, every operator recomputes it and refuses to sign a task whose
// executor differs — so the aggregator cannot steer settlement to a colluding operator.
//
//	executor = ordered[ keccak256(abi.encode(poolId, targetBlock, resultHash, seed)) % len ]
//
// ordered must be quorum 0 sorted by ID ascending (the canonical order all operators agree on).
// seed is prevrandao at referenceBlockNumber, read from chain — the one input not fixed by the
// relay's sealed payload. Caller guarantees len(ordered) >= 1 (there is always the designated operator).
func Executor(ordered []Operator, poolID [32]byte, targetBlock *big.Int, resultHash, seed [32]byte) [20]byte {
	h := keccak(concat(poolID[:], uintWord(targetBlock), resultHash[:], seed[:]))
	idx := new(big.Int).Mod(new(big.Int).SetBytes(h[:]), big.NewInt(int64(len(ordered)))).Int64()
	return ordered[idx].Addr
}
