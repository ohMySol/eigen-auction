package consensus

import (
	"math/big"
	"testing"
)

// Four quorum-0 operators, IDs ascending (canonical order); addr low byte tags the pick.
func operators() []Operator {
	mk := func(id, a byte) Operator { return Operator{ID: b32(id), Addr: addr(a)} }
	return []Operator{mk(1, 0xaa), mk(2, 0xbb), mk(3, 0xcc), mk(4, 0xdd)}
}

func b32(last byte) [32]byte {
	var x [32]byte
	x[31] = last
	return x
}

// Golden vector: the TS reference draw (§2.6) must select the same operator for these inputs.
func TestExecutorDraw(t *testing.T) {
	rh := Compute(arb(), price(), intents())
	got := Executor(operators(), poolID, big.NewInt(100), rh, b32(0x9))
	if got != addr(0xbb) {
		t.Fatalf("executor drift: got %x want %x", got, addr(0xbb))
	}
}

// A different seed (prevrandao) must be able to rotate the pick — the property mainnet relies on.
func TestExecutorSeedRotates(t *testing.T) {
	rh := Compute(arb(), price(), intents())
	seen := map[[20]byte]bool{}
	for s := byte(0); s < 16; s++ {
		seen[Executor(operators(), poolID, big.NewInt(100), rh, b32(s))] = true
	}
	if len(seen) < 2 {
		t.Fatalf("draw never rotated across 16 seeds: %d distinct", len(seen))
	}
}
