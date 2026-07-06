package chain

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"

	"github.com/ohMySol/eigen-auction/avs/internal/chaincfg"
	"github.com/ohMySol/eigen-auction/avs/internal/consensus"
	"github.com/ohMySol/eigen-auction/avs/internal/feed"
)

func TestSettlerOrderMapping(t *testing.T) {
	var searcher [20]byte
	searcher[19] = 0xa2
	var poolID [32]byte
	poolID[0] = 0x11
	o := consensus.ToBOrder{
		Searcher: searcher,
		PoolID: poolID,
		ZeroForOne: true,
		UseInternal: false,
		QuantityIn: big.NewInt(1000),
		QuantityOut: big.NewInt(500),
		ValidForBlock: big.NewInt(123),
	}
	got := SettlerOrder(o, []byte{0xde, 0xad})

	if got.Searcher != common.Address(searcher) || got.PoolId != poolID {
		t.Fatalf("addr/pool drift: %s %x", got.Searcher, got.PoolId)
	}
	if !got.ZeroForOne || got.UseInternal {
		t.Fatalf("flag drift")
	}
	if got.QuantityIn.Int64() != 1000 || got.QuantityOut.Int64() != 500 || got.ValidForBlock != 123 {
		t.Fatalf("quantity drift: %s %s %d", got.QuantityIn, got.QuantityOut, got.ValidForBlock)
	}
	if string(got.Signature) != "\xde\xad" {
		t.Fatalf("sig drift: %x", got.Signature)
	}
}

func TestSettlerOrderZeroArb(t *testing.T) {
	got := SettlerOrder(consensus.ToBOrder{}, nil)
	if got.QuantityIn.Sign() != 0 || got.QuantityOut.Sign() != 0 || got.ValidForBlock != 0 {
		t.Fatalf("zero arb should map to all-zero, got %s/%s/%d", got.QuantityIn, got.QuantityOut, got.ValidForBlock)
	}
}

func TestSettlerIntentsAndPoolKey(t *testing.T) {
	var user, poolID [20]byte
	user[19] = 0xb1
	intents := []feed.SignedIntent{{
		Intent: consensus.IntentTerms{
			User: user,
			ZeroForOne: false,
			AmountIn: big.NewInt(7),
			MinAmountOut: big.NewInt(6),
			Nonce: big.NewInt(9),
			Deadline: big.NewInt(1000),
		},
		Signature: []byte{0x01},
	}}
	out := SettlerIntents(intents)
	if len(out) != 1 || out[0].AmountIn.Int64() != 7 || out[0].Nonce != 9 || out[0].Deadline != 1000 {
		t.Fatalf("intent mapping drift: %+v", out)
	}

	d := &chaincfg.Deployment{Hook: common.HexToAddress("0x104")}
	d.Pool.Fee = 3000
	d.Pool.TickSpacing = 60
	k := PoolKey(d)
	if k.Fee.Int64() != 3000 || k.TickSpacing.Int64() != 60 || k.Hooks != d.Hook {
		t.Fatalf("poolkey drift: %+v", k)
	}
	_ = poolID
}
