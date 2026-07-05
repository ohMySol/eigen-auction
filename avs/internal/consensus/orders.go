package consensus

import "math/big"

// The Settler's EIP-712 domain constants (Settler constructor). name/version are hashed to bytes32.
var (
	domainTypehash = keccak([]byte("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"))
	settlerNameHash = keccak([]byte("EigenAuction Settler"))
	settlerVersionHash = keccak([]byte("1"))
)

// DomainSeparator reproduces the Settler's DOMAIN_SEPARATOR:
// keccak256(abi.encode(DOMAIN_TYPEHASH, keccak(name), keccak(version), chainId, settler)).
func DomainSeparator(settler [20]byte, chainID *big.Int) [32]byte {
	return keccak(concat(
		domainTypehash[:],
		settlerNameHash[:],
		settlerVersionHash[:],
		uintWord(chainID),
		addrWord(settler),
	))
}

// OrderDigest is the EIP-712 digest a searcher signs for an arb order (§2.5):
// keccak256(0x1901 ++ domainSeparator ++ toBStructHash(order)). Recovering this against the order's
// secp256k1 signature must yield order.Searcher; that recovery is done at the chain/operator layer,
// where go-ethereum is already a dependency. Byte-identical to the TS reference orderDigest.
func OrderDigest(o ToBOrder, settler [20]byte, chainID *big.Int) [32]byte {
	ds := DomainSeparator(settler, chainID)
	sh := ToBStructHash(o)
	return keccak([]byte{0x19, 0x01}, ds[:], sh[:])
}
