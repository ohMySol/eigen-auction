package feed

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/ohMySol/eigen-auction/avs/internal/consensus"
)

// price 2000<<128 as the relay would stamp it (decimal string), plus two arb orders where a2 leaves
// the greater LP surplus so rule A elects it — proving the decoded set flows straight into consensus.
func sealedJSON() (string, *big.Int) {
	price := new(big.Int).Lsh(big.NewInt(2000), 128)
	body := fmt.Sprintf(`{
      "targetBlock": 123,
      "referenceBlockNumber": 121,
      "clearingPriceX128": "%s",
      "orders": [
        {"searcher":"0x00000000000000000000000000000000000000a1","poolId":"0x1111111111111111111111111111111111111111111111111111111111111111",
         "zeroForOne":true,"useInternal":false,"quantityIn":"1000000000000000000","quantityOut":"1900000000000000000000","validForBlock":123,"signature":"0xabcd"},
        {"searcher":"0x00000000000000000000000000000000000000a2","poolId":"0x1111111111111111111111111111111111111111111111111111111111111111",
         "zeroForOne":true,"useInternal":false,"quantityIn":"1000000000000000000","quantityOut":"1500000000000000000000","validForBlock":123,"signature":"0x1234"}
      ],
      "intents": [
        {"user":"0x00000000000000000000000000000000000000b1","poolId":"0x1111111111111111111111111111111111111111111111111111111111111111",
         "zeroForOne":false,"useInternal":true,"amountIn":"5000000000000000000","minAmountOut":"4900000000000000000","nonce":7,"deadline":1000000,"signature":"0xdead"}
      ]
    }`, price.String())
	return body, price
}

func TestDecodeAndElect(t *testing.T) {
	body, price := sealedJSON()
	var set SealedSet
	if err := json.Unmarshal([]byte(body), &set); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if set.TargetBlock != 123 || set.ReferenceBlockNumber != 121 {
		t.Fatalf("header drift: %d / %d", set.TargetBlock, set.ReferenceBlockNumber)
	}
	if set.ClearingPriceX128.Cmp(price) != 0 {
		t.Fatalf("price drift: %s", set.ClearingPriceX128)
	}
	if len(set.Intents) != 1 || set.Intents[0].Intent.Nonce.Int64() != 7 {
		t.Fatalf("intent decode drift")
	}
	if string(set.Orders[0].Signature) != "\xab\xcd" {
		t.Fatalf("signature bytes drift: %x", set.Orders[0].Signature)
	}

	orders := []consensus.ToBOrder{set.Orders[0].Order, set.Orders[1].Order}
	w, ok := consensus.ElectWinner(orders, set.ClearingPriceX128)
	var wantA2 [20]byte
	wantA2[19] = 0xa2
	if !ok || w.Searcher != wantA2 {
		t.Fatalf("winner drift: ok=%v searcher=%x", ok, w.Searcher)
	}
}

func TestFetch(t *testing.T) {
	body, _ := sealedJSON()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/auction/123" {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		fmt.Fprint(w, body)
	}))
	defer srv.Close()

	set, err := NewClient(srv.URL).Fetch(context.Background(), 123)
	if err != nil {
		t.Fatalf("fetch: %v", err)
	}
	if set.TargetBlock != 123 || len(set.Orders) != 2 {
		t.Fatalf("fetched set drift: %+v", set)
	}

	if _, err := NewClient(srv.URL).Fetch(context.Background(), 999); err == nil {
		t.Fatal("expected error for missing block")
	}
}
