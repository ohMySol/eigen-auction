package chain

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"

	"github.com/ohMySol/eigen-auction/avs/internal/chain/bindings/settler"
	"github.com/ohMySol/eigen-auction/avs/internal/chaincfg"
	"github.com/ohMySol/eigen-auction/avs/internal/consensus"
	"github.com/ohMySol/eigen-auction/avs/internal/feed"
)

// These map the operator's pure consensus/feed values into the generated Settler tuples for the settle
// call. Kept as plain functions (not methods) so they're testable without a chain — the field order
// must line up with the ABI exactly or settle reverts on a resultHash mismatch.

func PoolKey(d *chaincfg.Deployment) settler.PoolKey {
	return settler.PoolKey{
		Currency0: d.Pool.Currency0,
		Currency1: d.Pool.Currency1,
		Fee: big.NewInt(int64(d.Pool.Fee)),
		TickSpacing: big.NewInt(int64(d.Pool.TickSpacing)),
		Hooks: d.Hook,
	}
}

// SettlerOrder maps a signed arb order to the Settler ToBOrder tuple. A zero order (no winner) maps to
// an all-zero arb, which the Settler treats as "no arb this block".
func SettlerOrder(o consensus.ToBOrder, sig []byte) settler.ToBOrder {
	return settler.ToBOrder{
		Searcher: common.Address(o.Searcher),
		PoolId: o.PoolID,
		ZeroForOne: o.ZeroForOne,
		UseInternal: o.UseInternal,
		QuantityIn: orZero(o.QuantityIn),
		QuantityOut: orZero(o.QuantityOut),
		ValidForBlock: toUint64(o.ValidForBlock),
		Signature: sig,
	}
}

func SettlerIntents(in []feed.SignedIntent) []settler.SwapIntent {
	out := make([]settler.SwapIntent, len(in))
	for i, si := range in {
		t := si.Intent
		out[i] = settler.SwapIntent{
			User: common.Address(t.User),
			PoolId: t.PoolID,
			ZeroForOne: t.ZeroForOne,
			UseInternal: t.UseInternal,
			AmountIn: orZero(t.AmountIn),
			MinAmountOut: orZero(t.MinAmountOut),
			Nonce: toUint64(t.Nonce),
			Deadline: toUint64(t.Deadline),
			Signature: si.Signature,
		}
	}
	return out
}

func orZero(v *big.Int) *big.Int {
	if v == nil {
		return big.NewInt(0)
	}
	return v
}

func toUint64(v *big.Int) uint64 {
	if v == nil {
		return 0
	}
	return v.Uint64()
}
