// Package chain is the operator/aggregator's on-chain adapter: secp256k1 order recovery (this file),
// contract bindings, and the read/commit/settle calls. It depends on go-ethereum, which is why the
// consensus package stays pure — the byte-exact hashing lives there, the key/RPC-bound work lives here.
package chain

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/crypto"

	"github.com/ohMySol/eigen-auction/avs/internal/consensus"
)

// RecoverToBOrderSigner recovers the searcher that signed an arb order (§2.5): it rebuilds the exact
// EIP-712 digest (consensus.OrderDigest) and ecrecovers the 65-byte secp256k1 signature, matching what
// EigenAuctionTaskManager._proveFraud verifies on-chain. An operator counts an order in the auction
// only when this returns order.Searcher — a cheap forgery filter before the (expensive) hashing round.
func RecoverToBOrderSigner(o consensus.ToBOrder, sig []byte, settler [20]byte, chainID *big.Int) ([20]byte, error) {
	var zero [20]byte
	if len(sig) != 65 {
		return zero, fmt.Errorf("bad order signature length %d, want 65", len(sig))
	}
	digest := consensus.OrderDigest(o, settler, chainID)

	// EIP-712 signatures carry v in {27,28}; go-ethereum's recover expects the recovery id {0,1}.
	rsv := make([]byte, 65)
	copy(rsv, sig)
	if rsv[64] >= 27 {
		rsv[64] -= 27
	}

	pub, err := crypto.SigToPub(digest[:], rsv)
	if err != nil {
		return zero, err
	}
	var addr [20]byte
	copy(addr[:], crypto.PubkeyToAddress(*pub).Bytes())
	return addr, nil
}
