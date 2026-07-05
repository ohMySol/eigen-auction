package consensus

import (
	"bytes"
	"math/big"
)

var q128 = new(big.Int).Lsh(big.NewInt(1), 128)

// ScoreOrder is the LP surplus an arb leaves at the clearing price, in token1 units scaled by Q128:
// quantityIn*clearingPriceX128 - quantityOut*Q128. Mirrors packages/shared/src/auction.ts.
func ScoreOrder(o ToBOrder, clearingPriceX128 *big.Int) *big.Int {
	in := new(big.Int).Mul(o.QuantityIn, clearingPriceX128)
	return in.Sub(in, new(big.Int).Mul(o.QuantityOut, q128))
}

// ElectWinner applies the frozen rule A: among orders with strictly positive surplus, pick the one
// with the greatest surplus; ties break on the lower toBStructHash so every operator elects the
// identical winner. ok is false when nothing is eligible — the block then commits with no arb
// (arbOrderHash = bytes32(0)). Byte-for-byte the same decision as the TS reference electWinner.
func ElectWinner(orders []ToBOrder, clearingPriceX128 *big.Int) (winner ToBOrder, ok bool) {
	var bestScore *big.Int
	var bestHash [32]byte
	for _, o := range orders {
		s := ScoreOrder(o, clearingPriceX128)
		if s.Sign() <= 0 {
			continue
		}
		h := ToBStructHash(o)
		if !ok || s.Cmp(bestScore) > 0 || (s.Cmp(bestScore) == 0 && bytes.Compare(h[:], bestHash[:]) < 0) {
			winner, ok, bestScore, bestHash = o, true, s, h
		}
	}
	return winner, ok
}
