// Package consensus is the operator's deterministic per-block core: the byte-exact commitment
// hashes (this file), winner election, and the executor draw. Every operator computes these from
// the same relay-sealed block payload and BLS-signs the resulting msgHash; the Settler re-derives
// resultHash and reverts a mismatch. Any divergence breaks the quorum, so the hashes here are held
// byte-identical to the Solidity (Settler.computeResultHash) and the TS reference
// (packages/shared/src/resultHash.ts) via the shared golden vectors in hashes_test.go.
//
// The ABI encodings are hand-packed (static words plus one dynamic bytes32[]) to keep the
// dependency surface at just Keccak; the golden vectors are the guardrail against a packing slip.
package consensus

import (
	"math/big"

	"golang.org/x/crypto/sha3"
)

// EIP-712 type strings, exactly as declared in the contracts; their keccak256 is the struct typehash.
var (
	tobOrderTypehash = keccak([]byte(
		"ToBOrder(address searcher,bytes32 poolId,bool zeroForOne,bool useInternal," +
			"uint128 quantityIn,uint128 quantityOut,uint64 validForBlock)"))
	intentTypehash = keccak([]byte(
		"SwapIntent(address user,bytes32 poolId,bool zeroForOne,bool useInternal," +
			"uint128 amountIn,uint128 minAmountOut,uint64 nonce,uint64 deadline)"))
)

// ToBOrder mirrors the Solidity struct's hashed fields (the signature is excluded from the hash).
type ToBOrder struct {
	Searcher [20]byte
	PoolID [32]byte
	ZeroForOne bool
	UseInternal bool
	QuantityIn *big.Int
	QuantityOut *big.Int
	ValidForBlock *big.Int
}

// IntentTerms mirrors the Solidity SwapIntent's hashed fields.
type IntentTerms struct {
	User [20]byte
	PoolID [32]byte
	ZeroForOne bool
	UseInternal bool
	AmountIn *big.Int
	MinAmountOut *big.Int
	Nonce *big.Int
	Deadline *big.Int
}

// ToBStructHash is keccak256(abi.encode(TYPEHASH, ...fields)).
func ToBStructHash(o ToBOrder) [32]byte {
	return keccak(concat(
		tobOrderTypehash[:],
		addrWord(o.Searcher),
		o.PoolID[:],
		boolWord(o.ZeroForOne),
		boolWord(o.UseInternal),
		uintWord(o.QuantityIn),
		uintWord(o.QuantityOut),
		uintWord(o.ValidForBlock),
	))
}

// IntentStructHash is keccak256(abi.encode(TYPEHASH, ...fields)).
func IntentStructHash(i IntentTerms) [32]byte {
	return keccak(concat(
		intentTypehash[:],
		addrWord(i.User),
		i.PoolID[:],
		boolWord(i.ZeroForOne),
		boolWord(i.UseInternal),
		uintWord(i.AmountIn),
		uintWord(i.MinAmountOut),
		uintWord(i.Nonce),
		uintWord(i.Deadline),
	))
}

// Compute mirrors Settler.computeResultHash:
//
//	arbOrderHash = hasArb ? ToBStructHash(arb) : bytes32(0)
//	intentsRoot  = keccak256(abi.encode(bytes32[] intentHashes))
//	resultHash   = keccak256(abi.encode(arbOrderHash, clearingPriceX128, intentsRoot))
//
// An all-zero arb (QuantityIn == QuantityOut == 0) means "no arb this block" and hashes to bytes32(0).
func Compute(arb ToBOrder, clearingPriceX128 *big.Int, intents []IntentTerms) [32]byte {
	var arbOrderHash [32]byte
	if arb.QuantityIn.Sign() != 0 || arb.QuantityOut.Sign() != 0 {
		arbOrderHash = ToBStructHash(arb)
	}

	// abi.encode(bytes32[]) is a dynamic array: head offset (0x20), length, then the elements.
	root := make([]byte, 0, 64+32*len(intents))
	root = append(root, uintWord(big.NewInt(32))...)
	root = append(root, uintWord(big.NewInt(int64(len(intents))))...)
	for _, it := range intents {
		h := IntentStructHash(it)
		root = append(root, h[:]...)
	}
	intentsRoot := keccak(root)

	return keccak(concat(
		arbOrderHash[:],
		uintWord(clearingPriceX128),
		intentsRoot[:],
	))
}

// MsgHash is the tuple the quorum BLS-signs, matching EigenAuctionTaskManager.commitWinner:
// keccak256(abi.encode(poolId, targetBlock, resultHash, executor)). Binding the executor into the
// signed hash is what makes the random executor draw trustless.
func MsgHash(poolID [32]byte, targetBlock *big.Int, resultHash [32]byte, executor [20]byte) [32]byte {
	return keccak(concat(
		poolID[:],
		uintWord(targetBlock),
		resultHash[:],
		addrWord(executor),
	))
}

// --- ABI word helpers: every value is right-aligned in a 32-byte word ---

func keccak(parts ...[]byte) [32]byte {
	h := sha3.NewLegacyKeccak256()
	for _, p := range parts {
		h.Write(p)
	}
	var out [32]byte
	h.Sum(out[:0])
	return out
}

func concat(parts ...[]byte) []byte {
	out := make([]byte, 0, 32*len(parts))
	for _, p := range parts {
		out = append(out, p...)
	}
	return out
}

// rightAlign copies b into the low bytes of a 32-byte word (ABI encoding of address/uint/bool).
func rightAlign(b []byte) []byte {
	w := make([]byte, 32)
	copy(w[32-len(b):], b)
	return w
}

func addrWord(a [20]byte) []byte { return rightAlign(a[:]) }

func uintWord(v *big.Int) []byte { return rightAlign(v.Bytes()) }

func boolWord(b bool) []byte {
	if b {
		return rightAlign([]byte{1})
	}
	return rightAlign(nil)
}
