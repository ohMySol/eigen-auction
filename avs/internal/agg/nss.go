// Package agg is the aggregator's core: mapping the blsagg aggregation result into the
// NonSignerStakesAndSignature tuple commitWinner expects (nss.go), and tracking per-block rounds
// (round.go). The eigensdk/registry wiring that feeds these lives in cmd/aggregator; the pieces here
// are pure so they stay unit-testable.
package agg

import (
	"math/big"

	"github.com/Layr-Labs/eigensdk-go/crypto/bls"
	blsagg "github.com/Layr-Labs/eigensdk-go/services/bls_aggregation"

	"github.com/ohMySol/eigen-auction/avs/internal/chain/bindings/taskmanager"
)

// g1/g2 convert eigensdk BLS points to the checker's BN254 structs. The coordinate math (and the G2
// A1/A0 swap) matches eigensdk's own chainioutils.ConvertToBN254* exactly — cross-checked in the test.
func g1(p *bls.G1Point) taskmanager.BN254G1Point {
	return taskmanager.BN254G1Point{X: p.X.BigInt(new(big.Int)), Y: p.Y.BigInt(new(big.Int))}
}

func g2(p *bls.G2Point) taskmanager.BN254G2Point {
	return taskmanager.BN254G2Point{
		X: [2]*big.Int{p.X.A1.BigInt(new(big.Int)), p.X.A0.BigInt(new(big.Int))},
		Y: [2]*big.Int{p.Y.A1.BigInt(new(big.Int)), p.Y.A0.BigInt(new(big.Int))},
	}
}

// NonSignerStakesAndSignature builds the tuple commitWinner passes to the BLSSignatureChecker from the
// blsagg service's aggregation response.
func NonSignerStakesAndSignature(r blsagg.BlsAggregationServiceResponse) taskmanager.IBLSSignatureCheckerTypesNonSignerStakesAndSignature {
	nss := taskmanager.IBLSSignatureCheckerTypesNonSignerStakesAndSignature{
		NonSignerQuorumBitmapIndices: r.NonSignerQuorumBitmapIndices,
		NonSignerPubkeys: make([]taskmanager.BN254G1Point, len(r.NonSignersPubkeysG1)),
		QuorumApks: make([]taskmanager.BN254G1Point, len(r.QuorumApksG1)),
		ApkG2: g2(r.SignersApkG2),
		Sigma: g1(r.SignersAggSigG1.G1Point),
		QuorumApkIndices: r.QuorumApkIndices,
		TotalStakeIndices: r.TotalStakeIndices,
		NonSignerStakeIndices: r.NonSignerStakeIndices,
	}
	for i, p := range r.NonSignersPubkeysG1 {
		nss.NonSignerPubkeys[i] = g1(p)
	}
	for i, p := range r.QuorumApksG1 {
		nss.QuorumApks[i] = g1(p)
	}
	return nss
}
