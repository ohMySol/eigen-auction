package operator

import (
	"encoding/hex"
	"math/big"
	"testing"

	"github.com/ohMySol/eigen-auction/avs/internal/consensus"
	"github.com/ohMySol/eigen-auction/avs/internal/feed"
)

// Validly-signed arb order from the TS signer (anvil acct #1) — same fixture as the chain package, so
// RecoverToBOrderSigner accepts it and it wins the auction. Lets Resolve run the whole pipeline for real.
const (
	signerHex = "70997970c51812dc3a010c7d01b50e0d17dc79c8"
	sigHex    = "39d18f198af43ee4a982c39a75afc33d817cd9e9e88b75206adcbaecbb5ca590766edc538fa3ef01d68015d8b57582aae5499b656e0ec3f1fc19c83f6390ce011b"
)

func mustHex(t *testing.T, h string) []byte {
	t.Helper()
	b, err := hex.DecodeString(h)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func fixture(t *testing.T) (*feed.SealedSet, [32]byte, [20]byte, *big.Int, []consensus.Operator, [20]byte) {
	var signer, settler [20]byte
	copy(signer[:], mustHex(t, signerHex))
	settler[18], settler[19] = 0xde, 0xad
	var poolID [32]byte
	for i := range poolID {
		poolID[i] = 0x11
	}
	order := consensus.ToBOrder{
		Searcher: signer,
		PoolID: poolID,
		ZeroForOne: true,
		UseInternal: false,
		QuantityIn: big.NewInt(1_050_000_000_000_000_000),
		QuantityOut: big.NewInt(1_000_000_000_000_000_000),
		ValidForBlock: big.NewInt(100),
	}
	set := &feed.SealedSet{
		TargetBlock: 100,
		ReferenceBlockNumber: 98,
		ClearingPriceX128: new(big.Int).Lsh(big.NewInt(2000), 128),
		Orders: []feed.SignedOrder{{Order: order, Signature: mustHex(t, sigHex)}},
	}
	ops := []consensus.Operator{
		{ID: [32]byte{31: 1}, Addr: [20]byte{19: 0xaa}},
		{ID: [32]byte{31: 2}, Addr: [20]byte{19: 0xbb}},
		{ID: [32]byte{31: 3}, Addr: [20]byte{19: 0xcc}},
	}
	return set, poolID, settler, big.NewInt(31337), ops, signer
}

func TestResolveElectsSignedWinner(t *testing.T) {
	set, poolID, settler, chainID, ops, signer := fixture(t)
	seed := [32]byte{31: 0x9}

	d := Resolve(set, poolID, seed, ops, settler, chainID)
	if !d.HasArb || d.Arb.Searcher != signer {
		t.Fatalf("expected signed order to win: hasArb=%v searcher=%x", d.HasArb, d.Arb.Searcher)
	}
	if hex.EncodeToString(d.ArbSig) != sigHex {
		t.Fatalf("winner sig drift: %x", d.ArbSig)
	}
	// executor must be one of the quorum, and the whole decision is deterministic.
	found := false
	for _, o := range ops {
		if o.Addr == d.Executor {
			found = true
		}
	}
	if !found {
		t.Fatalf("executor %x not in quorum", d.Executor)
	}
	if d2 := Resolve(set, poolID, seed, ops, settler, chainID); d2.MsgHash != d.MsgHash {
		t.Fatalf("Resolve not deterministic")
	}
}

func TestResolveDropsForgedOrder(t *testing.T) {
	set, poolID, settler, chainID, ops, _ := fixture(t)
	set.Orders[0].Signature[0] ^= 0xff // corrupt the signature

	d := Resolve(set, poolID, [32]byte{31: 0x9}, ops, settler, chainID)
	if d.HasArb {
		t.Fatalf("forged-signature order must not win")
	}
	// With no valid arb the result must equal the no-arb commitment.
	noArb := consensus.Compute(consensus.ToBOrder{QuantityIn: big.NewInt(0), QuantityOut: big.NewInt(0)}, set.ClearingPriceX128, nil)
	if d.ResultHash != noArb {
		t.Fatalf("no-arb resultHash drift")
	}
}
