// Package attest is the operator→aggregator wire contract. Each operator independently computes the
// block (operator.Resolve), BLS-signs the msgHash, and POSTs a SignedResponse; the aggregator feeds
// (msgHash, signature, operatorId) into eigensdk's blsagg and, once quorum stake has signed, builds
// commitWinner from the agreed commitment fields carried here. All operators send identical commitment
// fields (that's the whole point of the deterministic core), so the aggregator can trust any of them.
package attest

import (
	"github.com/Layr-Labs/eigensdk-go/crypto/bls"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"

	"github.com/ohMySol/eigen-auction/avs/internal/operator"
)

type SignedResponse struct {
	PoolID common.Hash `json:"poolId"`
	TargetBlock uint64 `json:"targetBlock"`
	ReferenceBlockNumber uint32 `json:"referenceBlockNumber"`
	ResultHash common.Hash `json:"resultHash"`
	Executor common.Address `json:"executor"`
	MsgHash common.Hash `json:"msgHash"`
	OperatorID common.Hash `json:"operatorId"`
	SigG1 hexutil.Bytes `json:"sigG1"` // serialized BLS G1 signature
}

// Build assembles the response an operator sends the aggregator: the agreed commitment fields from
// Resolve plus this operator's BLS signature over msgHash.
func Build(res operator.Result, poolID [32]byte, targetBlock uint64, refBlock uint32, operatorID [32]byte, sig *bls.Signature) SignedResponse {
	return SignedResponse{
		PoolID: poolID,
		TargetBlock: targetBlock,
		ReferenceBlockNumber: refBlock,
		ResultHash: res.ResultHash,
		Executor: res.Executor,
		MsgHash: res.MsgHash,
		OperatorID: operatorID,
		SigG1: sig.Serialize(),
	}
}

// Signature reconstructs the BLS signature from the wire bytes so the aggregator can feed it to blsagg.
func (r SignedResponse) Signature() *bls.Signature {
	return &bls.Signature{G1Point: bls.NewZeroG1Point().Deserialize(r.SigG1)}
}
