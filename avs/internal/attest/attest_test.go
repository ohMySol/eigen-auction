package attest

import (
	"encoding/json"
	"testing"

	"github.com/Layr-Labs/eigensdk-go/crypto/bls"

	"github.com/ohMySol/eigen-auction/avs/internal/operator"
)

// Signs a msgHash, ships the response over JSON, reconstructs the signature on the other side, and
// verifies it against the operator's G2 pubkey — the full operator→aggregator BLS path, no chain.
func TestSignedResponseRoundTrip(t *testing.T) {
	kp, err := bls.GenRandomBlsKeys()
	if err != nil {
		t.Fatal(err)
	}
	var msg [32]byte
	msg[0], msg[31] = 0xab, 0xcd
	res := operator.Result{ResultHash: [32]byte{1: 0x11}, Executor: [20]byte{19: 0xe0}, MsgHash: msg}

	sr := Build(res, [32]byte{31: 0x9}, 100, 98, [32]byte{31: 0x7}, kp.SignMessage(msg))

	wire, err := json.Marshal(sr)
	if err != nil {
		t.Fatal(err)
	}
	var back SignedResponse
	if err := json.Unmarshal(wire, &back); err != nil {
		t.Fatal(err)
	}
	if back.TargetBlock != 100 || back.ReferenceBlockNumber != 98 || back.MsgHash != msg {
		t.Fatalf("header drift: %+v", back)
	}

	ok, err := back.Signature().Verify(kp.GetPubKeyG2(), msg)
	if err != nil || !ok {
		t.Fatalf("signature must verify: ok=%v err=%v", ok, err)
	}
	// A different message must not verify under the same signature.
	if bad, _ := back.Signature().Verify(kp.GetPubKeyG2(), [32]byte{0xff}); bad {
		t.Fatal("signature verified against the wrong message")
	}
}
