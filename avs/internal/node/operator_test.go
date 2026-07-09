package node

import (
	"context"
	"encoding/hex"
	"math/big"
	"testing"

	"github.com/Layr-Labs/eigensdk-go/crypto/bls"

	"github.com/ohMySol/eigen-auction/avs/internal/attest"
	"github.com/ohMySol/eigen-auction/avs/internal/consensus"
	"github.com/ohMySol/eigen-auction/avs/internal/feed"
)

// Validly-signed arb order from the TS signer (anvil acct #1), same fixture as the operator package.
const (
	signerHex = "70997970c51812dc3a010c7d01b50e0d17dc79c8"
	sigHex    = "39d18f198af43ee4a982c39a75afc33d817cd9e9e88b75206adcbaecbb5ca590766edc538fa3ef01d68015d8b57582aae5499b656e0ec3f1fc19c83f6390ce011b"
)

type fakeFeed struct{ set *feed.SealedSet }

func (f fakeFeed) Fetch(context.Context, uint64) (*feed.SealedSet, error) { return f.set, nil }

type fakeRandao struct{ seed [32]byte }

func (f fakeRandao) Prevrandao(context.Context, uint64) ([32]byte, error) { return f.seed, nil }

type fakeQuorum struct{ ops []consensus.Operator }

func (f fakeQuorum) QuorumZero(context.Context, uint64) ([]consensus.Operator, error) {
	return f.ops, nil
}

type capture struct{ got attest.SignedResponse }

func (c *capture) Submit(_ context.Context, r attest.SignedResponse) error {
	c.got = r
	return nil
}

func TestRunBlockSignsAndSubmits(t *testing.T) {
	sig, _ := hex.DecodeString(sigHex)
	var signer, settler [20]byte
	copy(signer[:], mustHex(t, signerHex))
	settler[18], settler[19] = 0xde, 0xad
	var poolID [32]byte
	for i := range poolID {
		poolID[i] = 0x11
	}
	order := consensus.ToBOrder{
		Searcher: signer, PoolID: poolID, ZeroForOne: true, UseInternal: false,
		QuantityIn: big.NewInt(1_050_000_000_000_000_000), QuantityOut: big.NewInt(1_000_000_000_000_000_000),
		ValidForBlock: big.NewInt(100),
	}
	set := &feed.SealedSet{
		TargetBlock: 100, ReferenceBlockNumber: 98,
		ClearingPriceX128: new(big.Int).Lsh(big.NewInt(2000), 128),
		Orders: []feed.SignedOrder{{Order: order, Signature: sig}},
	}
	ops := []consensus.Operator{
		{ID: [32]byte{31: 1}, Addr: [20]byte{19: 0xaa}},
		{ID: [32]byte{31: 2}, Addr: [20]byte{19: 0xbb}},
	}

	kp, err := bls.GenRandomBlsKeys()
	if err != nil {
		t.Fatal(err)
	}
	sink := &capture{}
	op := &Operator{
		PoolID: poolID, Settler: settler, ChainID: big.NewInt(31337),
		OperatorID: [32]byte{31: 7}, Keys: kp,
		Feed: fakeFeed{set}, Chain: fakeRandao{[32]byte{31: 0x9}}, Quorum: fakeQuorum{ops}, Submitter: sink,
	}

	_, res, submitted, err := op.RunBlock(context.Background(), 100)
	if err != nil {
		t.Fatalf("RunBlock: %v", err)
	}
	if !submitted {
		t.Fatalf("expected a non-empty set to be submitted")
	}
	if !res.HasArb || res.Arb.Searcher != signer {
		t.Fatalf("expected the signed order to win")
	}

	// The submitted response must carry this block's commitment and a signature that verifies.
	if sink.got.ResultHash != res.ResultHash || sink.got.Executor != res.Executor {
		t.Fatalf("submitted commitment drift")
	}
	ok, err := sink.got.Signature().Verify(kp.GetPubKeyG2(), res.MsgHash)
	if err != nil || !ok {
		t.Fatalf("submitted BLS signature must verify: ok=%v err=%v", ok, err)
	}
}

func TestRunBlockSkipsEmptySet(t *testing.T) {
	kp, err := bls.GenRandomBlsKeys()
	if err != nil {
		t.Fatal(err)
	}
	sink := &capture{}
	empty := &feed.SealedSet{TargetBlock: 100, ReferenceBlockNumber: 99, ClearingPriceX128: big.NewInt(1)}
	op := &Operator{
		ChainID: big.NewInt(31337), Keys: kp,
		Feed: fakeFeed{empty}, Chain: fakeRandao{}, Quorum: fakeQuorum{}, Submitter: sink,
	}
	_, _, submitted, err := op.RunBlock(context.Background(), 100)
	if err != nil {
		t.Fatalf("RunBlock: %v", err)
	}
	if submitted {
		t.Fatal("an empty sealed set must not open a round")
	}
	if sink.got.SigG1 != nil {
		t.Fatal("nothing should have been submitted for an empty set")
	}
}

func mustHex(t *testing.T, h string) []byte {
	t.Helper()
	b, err := hex.DecodeString(h)
	if err != nil {
		t.Fatal(err)
	}
	return b
}
