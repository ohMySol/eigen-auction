package agg

import (
	"math/big"
	"testing"

	"github.com/Layr-Labs/eigensdk-go/chainio/utils"
	"github.com/Layr-Labs/eigensdk-go/crypto/bls"
	blsagg "github.com/Layr-Labs/eigensdk-go/services/bls_aggregation"
)

// Cross-check our BN254 conversion against eigensdk's own chainioutils.ConvertToBN254* — if the
// coordinate math (or the G2 A1/A0 swap) drifts, the aggregate fails the on-chain pairing check.
func TestNonSignerStakesAndSignatureConversion(t *testing.T) {
	kp, err := bls.GenRandomBlsKeys()
	if err != nil {
		t.Fatal(err)
	}
	var msg [32]byte
	msg[0] = 0x11
	sig := kp.SignMessage(msg)

	r := blsagg.BlsAggregationServiceResponse{
		NonSignersPubkeysG1: []*bls.G1Point{kp.GetPubKeyG1()},
		QuorumApksG1: []*bls.G1Point{kp.GetPubKeyG1()},
		SignersApkG2: kp.GetPubKeyG2(),
		SignersAggSigG1: sig,
		NonSignerQuorumBitmapIndices: []uint32{0},
		QuorumApkIndices: []uint32{1},
		TotalStakeIndices: []uint32{2},
		NonSignerStakeIndices: [][]uint32{{3}},
	}
	nss := NonSignerStakesAndSignature(r)

	// G1 sigma must equal eigensdk's converter output.
	wantSigma := utils.ConvertToBN254G1Point(sig.G1Point)
	if nss.Sigma.X.Cmp(wantSigma.X) != 0 || nss.Sigma.Y.Cmp(wantSigma.Y) != 0 {
		t.Fatalf("sigma drift: got (%s,%s) want (%s,%s)", nss.Sigma.X, nss.Sigma.Y, wantSigma.X, wantSigma.Y)
	}
	// G2 apk (with the A1/A0 swap) must equal eigensdk's converter output.
	wantApk := utils.ConvertToBN254G2Point(kp.GetPubKeyG2())
	if nss.ApkG2.X[0].Cmp(wantApk.X[0]) != 0 || nss.ApkG2.X[1].Cmp(wantApk.X[1]) != 0 ||
		nss.ApkG2.Y[0].Cmp(wantApk.Y[0]) != 0 || nss.ApkG2.Y[1].Cmp(wantApk.Y[1]) != 0 {
		t.Fatalf("apkG2 drift")
	}
	// Pass-through index fields must survive intact.
	if len(nss.NonSignerPubkeys) != 1 || len(nss.QuorumApks) != 1 ||
		nss.QuorumApkIndices[0] != 1 || nss.TotalStakeIndices[0] != 2 || nss.NonSignerStakeIndices[0][0] != 3 {
		t.Fatalf("index passthrough drift: %+v", nss)
	}
	_ = big.NewInt(0)
}
