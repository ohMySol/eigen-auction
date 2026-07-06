package chaincfg

import (
	"strings"
	"testing"

	"github.com/ethereum/go-ethereum/common"
)

func TestLoad(t *testing.T) {
	d, err := Load("testdata", 31337)
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	if d.Settler != common.HexToAddress("0x000000000000000000000000000000000000dead") {
		t.Fatalf("settler: %s", d.Settler)
	}
	if d.TaskManager != common.HexToAddress("0x0000000000000000000000000000000000000105") {
		t.Fatalf("taskManager: %s", d.TaskManager)
	}
	if d.Pool.Currency1Decimals != 6 {
		t.Fatalf("currency1Decimals: %d", d.Pool.Currency1Decimals)
	}
	if d.Pool.PoolID != common.HexToHash("0x1111111111111111111111111111111111111111111111111111111111111111") {
		t.Fatalf("poolId: %s", d.Pool.PoolID)
	}
}

func TestLoadChainIDMismatch(t *testing.T) {
	if _, err := Load("testdata", 1); err == nil || !strings.Contains(err.Error(), "read deployment") {
		t.Fatalf("expected missing-file error, got %v", err)
	}
}
