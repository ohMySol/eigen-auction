package consensus

import (
	"math/big"
	"testing"
)

// Golden vectors shared with packages/shared/test/auction.test.ts — the two legs of rule A must
// elect the identical winner from the identical inputs.
func e18(n int64) *big.Int {
	return new(big.Int).Mul(big.NewInt(n), big.NewInt(1_000_000_000_000_000_000))
}

func ord(searcher byte, qin, qout *big.Int) ToBOrder {
	return ToBOrder{
		Searcher: addr(searcher),
		PoolID: poolID,
		ZeroForOne: true,
		UseInternal: false,
		QuantityIn: qin,
		QuantityOut: qout,
		ValidForBlock: big.NewInt(100),
	}
}

func TestScoreOrder(t *testing.T) {
	b := ord(0xa2, e18(1), e18(1500))
	want := new(big.Int).Mul(e18(500), q128)
	if got := ScoreOrder(b, price()); got.Cmp(want) != 0 {
		t.Fatalf("score drift: got %s want %s", got, want)
	}
}

func TestElectWinner(t *testing.T) {
	a := ord(0xa1, e18(1), e18(1900)) // surplus 100e18
	b := ord(0xa2, e18(1), e18(1500)) // surplus 500e18 — best
	c := ord(0xa3, e18(1), e18(2100)) // surplus -100e18 — ineligible

	w, ok := ElectWinner([]ToBOrder{a, b, c}, price())
	if !ok || w.Searcher != addr(0xa2) {
		t.Fatalf("winner drift: ok=%v searcher=%x", ok, w.Searcher)
	}
	if _, ok := ElectWinner([]ToBOrder{c}, price()); ok {
		t.Fatalf("non-positive-surplus order should be ineligible")
	}
	if _, ok := ElectWinner(nil, price()); ok {
		t.Fatalf("empty order set should have no winner")
	}
}

func TestElectWinnerTiebreakStable(t *testing.T) {
	d := ord(0xd1, e18(2), e18(3900)) // surplus 100e18
	e := ord(0xe1, e18(2), e18(3900)) // surplus 100e18, same score
	w1, _ := ElectWinner([]ToBOrder{d, e}, price())
	w2, _ := ElectWinner([]ToBOrder{e, d}, price())
	if w1.Searcher != w2.Searcher {
		t.Fatalf("tiebreak not order-independent: %x vs %x", w1.Searcher, w2.Searcher)
	}
}
