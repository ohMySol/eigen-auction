package consensus

import (
	"encoding/hex"
	"math/big"
	"testing"
)

// Golden vectors shared with src/contracts/test/unit/ResultHashVectors.t.sol and
// packages/shared/test/resultHash.test.ts. The Solidity side generates them from the real
// Settler.computeResultHash; asserting the same literals here makes Go the third byte-identical leg.
// Keep the inputs in lockstep with the other two suites.

var poolID = mustBytes32("1111111111111111111111111111111111111111111111111111111111111111")

func addr(last byte) [20]byte {
	var a [20]byte
	a[19] = last
	return a
}

func arb() ToBOrder {
	return ToBOrder{
		Searcher: addr(0xa1),
		PoolID: poolID,
		ZeroForOne: true,
		UseInternal: false,
		QuantityIn: big.NewInt(1_050_000_000_000_000_000), // 1.05e18
		QuantityOut: big.NewInt(1_000_000_000_000_000_000), // 1e18
		ValidForBlock: big.NewInt(100),
	}
}

func intents() []IntentTerms {
	return []IntentTerms{
		{
			User: addr(0xb1),
			PoolID: poolID,
			ZeroForOne: false,
			UseInternal: true,
			AmountIn: big.NewInt(5_000_000_000_000_000_000), // 5e18
			MinAmountOut: big.NewInt(4_900_000_000_000_000_000), // 4.9e18
			Nonce: big.NewInt(7),
			Deadline: big.NewInt(1_000_000),
		},
		{
			User: addr(0xb2),
			PoolID: poolID,
			ZeroForOne: true,
			UseInternal: false,
			AmountIn: big.NewInt(2_000_000_000_000_000_000), // 2e18
			MinAmountOut: big.NewInt(1_900_000_000_000_000_000), // 1.9e18
			Nonce: big.NewInt(8),
			Deadline: big.NewInt(2_000_000),
		},
	}
}

// price = 2000 << 128
func price() *big.Int { return new(big.Int).Lsh(big.NewInt(2000), 128) }

func TestToBStructHash(t *testing.T) {
	assertHash(t, ToBStructHash(arb()), "623d60f3f55e097ac6780b2e8b72874564238438fdd60c39df059e5a7506a0fb")
}

func TestComputeWithArb(t *testing.T) {
	assertHash(t, Compute(arb(), price(), intents()), "e7c8f352536e6767c8d9e173dbaa5ed772196e83f2b75dc76e084629119a3f80")
}

func TestComputeNoArb(t *testing.T) {
	empty := arb()
	empty.QuantityIn = big.NewInt(0)
	empty.QuantityOut = big.NewInt(0)
	assertHash(t, Compute(empty, price(), intents()), "7c8574d6b61317609623f598d388490de3f68f37cdd8ff1494c6ec4a27472cb8")
}

func TestMsgHash(t *testing.T) {
	resultWithArb := Compute(arb(), price(), intents())
	got := MsgHash(poolID, big.NewInt(12345), resultWithArb, addr(0xe0))
	assertHash(t, got, "7a1f4129018aaa5892805e2a99113cd3e2582e74cfe1fc3d50787229449f10f2")
}

func assertHash(t *testing.T, got [32]byte, wantHex string) {
	t.Helper()
	if h := hex.EncodeToString(got[:]); h != wantHex {
		t.Fatalf("hash drift:\n got  0x%s\n want 0x%s", h, wantHex)
	}
}

func mustBytes32(h string) [32]byte {
	b, err := hex.DecodeString(h)
	if err != nil || len(b) != 32 {
		panic("bad bytes32 literal")
	}
	var out [32]byte
	copy(out[:], b)
	return out
}
