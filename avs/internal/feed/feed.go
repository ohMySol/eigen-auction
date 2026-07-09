// Package feed is the operator's read side of the relay: it fetches the block's sealed bid+intent set
// and decodes it into the consensus types. Every operator GETs the identical byte payload for block N
// (the relay's pull-at-cutoff seal), so all operators trivially agree on the auction inputs.
//
// Wire contract (what the TS relay must emit): a JSON object per block. bigints (quantities, clearing
// price) are decimal strings — JSON has no bigint; addresses/poolId/signatures are 0x-hex. This is the
// canonical shape the relay's /auction/{block} endpoint serves; the TS relay conforms to it.
package feed

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"

	"github.com/ohMySol/eigen-auction/avs/internal/consensus"
)

// SignedOrder / SignedIntent pair the consensus terms with the searcher/user signature the operator
// verifies before counting them.
type SignedOrder struct {
	Order consensus.ToBOrder
	Signature []byte
}

type SignedIntent struct {
	Intent consensus.IntentTerms
	Signature []byte
}

// SealedSet is the relay's canonical, ordered payload for one target block. Every consensus input the
// operator needs is stamped here except prevrandao (read from chain at ReferenceBlockNumber).
type SealedSet struct {
	TargetBlock uint64
	ReferenceBlockNumber uint32
	ClearingPriceX128 *big.Int
	Orders []SignedOrder
	Intents []SignedIntent
}

// --- wire representation (JSON) ---

type wireOrder struct {
	Searcher common.Address `json:"searcher"`
	PoolID common.Hash `json:"poolId"`
	ZeroForOne bool `json:"zeroForOne"`
	UseInternal bool `json:"useInternal"`
	QuantityIn string `json:"quantityIn"`
	QuantityOut string `json:"quantityOut"`
	ValidForBlock uint64 `json:"validForBlock"`
	Signature hexutil.Bytes `json:"signature"`
}

type wireIntent struct {
	User common.Address `json:"user"`
	PoolID common.Hash `json:"poolId"`
	ZeroForOne bool `json:"zeroForOne"`
	UseInternal bool `json:"useInternal"`
	AmountIn string `json:"amountIn"`
	MinAmountOut string `json:"minAmountOut"`
	Nonce uint64 `json:"nonce"`
	Deadline uint64 `json:"deadline"`
	Signature hexutil.Bytes `json:"signature"`
}

type wireSealedSet struct {
	TargetBlock uint64 `json:"targetBlock"`
	ReferenceBlockNumber uint32 `json:"referenceBlockNumber"`
	ClearingPriceX128 string `json:"clearingPriceX128"`
	Orders []wireOrder `json:"orders"`
	Intents []wireIntent `json:"intents"`
}

func decInt(field, s string) (*big.Int, error) {
	v, ok := new(big.Int).SetString(s, 10)
	if !ok {
		return nil, fmt.Errorf("invalid decimal %s: %q", field, s)
	}
	return v, nil
}

// UnmarshalJSON parses the wire shape into the consensus types, converting decimal-string bigints and
// rejecting a malformed payload up front so the auction never runs on a half-decoded set.
func (s *SealedSet) UnmarshalJSON(b []byte) error {
	var w wireSealedSet
	if err := json.Unmarshal(b, &w); err != nil {
		return err
	}
	price, err := decInt("clearingPriceX128", w.ClearingPriceX128)
	if err != nil {
		return err
	}
	out := SealedSet{
		TargetBlock: w.TargetBlock,
		ReferenceBlockNumber: w.ReferenceBlockNumber,
		ClearingPriceX128: price,
		Orders: make([]SignedOrder, len(w.Orders)),
		Intents: make([]SignedIntent, len(w.Intents)),
	}
	for i, o := range w.Orders {
		qin, err := decInt("quantityIn", o.QuantityIn)
		if err != nil {
			return err
		}
		qout, err := decInt("quantityOut", o.QuantityOut)
		if err != nil {
			return err
		}
		out.Orders[i] = SignedOrder{
			Order: consensus.ToBOrder{
				Searcher: o.Searcher,
				PoolID: o.PoolID,
				ZeroForOne: o.ZeroForOne,
				UseInternal: o.UseInternal,
				QuantityIn: qin,
				QuantityOut: qout,
				ValidForBlock: new(big.Int).SetUint64(o.ValidForBlock),
			},
			Signature: o.Signature,
		}
	}
	for i, it := range w.Intents {
		amt, err := decInt("amountIn", it.AmountIn)
		if err != nil {
			return err
		}
		minOut, err := decInt("minAmountOut", it.MinAmountOut)
		if err != nil {
			return err
		}
		out.Intents[i] = SignedIntent{
			Intent: consensus.IntentTerms{
				User: it.User,
				PoolID: it.PoolID,
				ZeroForOne: it.ZeroForOne,
				UseInternal: it.UseInternal,
				AmountIn: amt,
				MinAmountOut: minOut,
				Nonce: new(big.Int).SetUint64(it.Nonce),
				Deadline: new(big.Int).SetUint64(it.Deadline),
			},
			Signature: it.Signature,
		}
	}
	*s = out
	return nil
}

// Client fetches sealed sets from the relay.
type Client struct {
	BaseURL string
	HTTP *http.Client
}

func NewClient(baseURL string) *Client {
	return &Client{BaseURL: baseURL, HTTP: &http.Client{Timeout: 3 * time.Second}}
}

// Fetch GETs {BaseURL}/auction/{block} and decodes the sealed set for that block.
func (c *Client) Fetch(ctx context.Context, block uint64) (*SealedSet, error) {
	url := fmt.Sprintf("%s/auction/%d", c.BaseURL, block)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("feed %s: status %d", url, resp.StatusCode)
	}
	var set SealedSet
	if err := json.NewDecoder(resp.Body).Decode(&set); err != nil {
		return nil, fmt.Errorf("decode sealed set: %w", err)
	}
	return &set, nil
}
