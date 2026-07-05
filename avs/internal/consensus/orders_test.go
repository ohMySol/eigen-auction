package consensus

import (
	"math/big"
	"testing"
)

// Golden vector shared with packages/shared/test/sign.test.ts — the arb-order EIP-712 digest must be
// byte-identical across the TS reference and Go so an operator recovers the same searcher the contract
// would. settler/chainId match the TS ORDER_SETTLER / 31337.
func TestOrderDigest(t *testing.T) {
	var settler [20]byte
	settler[18], settler[19] = 0xde, 0xad // 0x...dead
	got := OrderDigest(arb(), settler, big.NewInt(31337))
	assertHash(t, got, "d094e0848e3c0dfcf82febe4aec69df2393ebb158ce6338ec15ef96e379ac9a4")
}
