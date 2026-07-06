package agg

import (
	"fmt"
	"sync"

	"github.com/ohMySol/eigen-auction/avs/internal/attest"
)

// Round is the commitment metadata the aggregator remembers for a task so it can build commitWinner
// once blsagg reaches quorum. All operators submit identical fields, so the first one seen is canonical.
type Round struct {
	PoolID [32]byte
	TargetBlock uint64
	ReferenceBlock uint32
	ResultHash [32]byte
	Executor [20]byte
	MsgHash [32]byte
}

// Rounds maps each (poolId, targetBlock) to a stable blsagg task index and remembers its Round. Safe
// for concurrent use — the HTTP handler and the aggregation-response reader both touch it.
type Rounds struct {
	mu sync.Mutex
	byKey map[string]uint32
	byIndex map[uint32]Round
	next uint32
}

func NewRounds() *Rounds {
	return &Rounds{byKey: map[string]uint32{}, byIndex: map[uint32]Round{}}
}

func key(poolID [32]byte, targetBlock uint64) string {
	return fmt.Sprintf("%x:%d", poolID, targetBlock)
}

// Track returns the task index for a response's (poolId, targetBlock), creating one the first time.
// isNew is true only on first sight, signalling the caller to InitializeNewTask on the blsagg service.
func (r *Rounds) Track(sr attest.SignedResponse) (index uint32, isNew bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	k := key(sr.PoolID, sr.TargetBlock)
	if idx, ok := r.byKey[k]; ok {
		return idx, false
	}
	idx := r.next
	r.next++
	r.byKey[k] = idx
	r.byIndex[idx] = Round{
		PoolID: sr.PoolID,
		TargetBlock: sr.TargetBlock,
		ReferenceBlock: sr.ReferenceBlockNumber,
		ResultHash: sr.ResultHash,
		Executor: sr.Executor,
		MsgHash: sr.MsgHash,
	}
	return idx, true
}

func (r *Rounds) Get(index uint32) (Round, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	rd, ok := r.byIndex[index]
	return rd, ok
}
