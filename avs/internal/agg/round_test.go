package agg

import (
	"testing"

	"github.com/ethereum/go-ethereum/common"

	"github.com/ohMySol/eigen-auction/avs/internal/attest"
)

func resp(pool byte, block uint64) attest.SignedResponse {
	var p common.Hash
	p[31] = pool
	return attest.SignedResponse{PoolID: p, TargetBlock: block, ReferenceBlockNumber: uint32(block - 2), Executor: common.Address{19: 0xe0}}
}

func TestRoundsTrackAssignsStableIndices(t *testing.T) {
	r := NewRounds()

	i0, new0 := r.Track(resp(1, 100))
	if !new0 || i0 != 0 {
		t.Fatalf("first task: index=%d new=%v", i0, new0)
	}
	// Same (pool, block) → same index, not new.
	if i, isNew := r.Track(resp(1, 100)); i != 0 || isNew {
		t.Fatalf("dedup failed: index=%d new=%v", i, isNew)
	}
	// Different block → new index.
	if i, isNew := r.Track(resp(1, 101)); i != 1 || !isNew {
		t.Fatalf("second task: index=%d new=%v", i, isNew)
	}
	// Different pool, same block → new index.
	if i, isNew := r.Track(resp(2, 100)); i != 2 || !isNew {
		t.Fatalf("third task: index=%d new=%v", i, isNew)
	}

	rd, ok := r.Get(0)
	if !ok || rd.TargetBlock != 100 || rd.ReferenceBlock != 98 {
		t.Fatalf("round metadata drift: %+v", rd)
	}
	if _, ok := r.Get(99); ok {
		t.Fatal("unknown index should not resolve")
	}
}
