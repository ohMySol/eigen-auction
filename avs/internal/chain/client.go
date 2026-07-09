package chain

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"

	"github.com/ohMySol/eigen-auction/avs/internal/chain/bindings/settler"
	"github.com/ohMySol/eigen-auction/avs/internal/chain/bindings/taskmanager"
)

// Client is the typed connection to the chain shared by the operator and aggregator: the drawn
// executor settles via Settler, the aggregator commits via TaskManager, and every operator reads
// prevrandao for the executor draw. The generated bindings (c.Settler / c.TaskManager) carry the
// typed Settle / CommitWinner / GetCommitment methods; this wrapper just wires them to one RPC.
type Client struct {
	eth *ethclient.Client
	Settler *settler.Settler
	TaskManager *taskmanager.TaskManager
	ChainID *big.Int
}

func Dial(ctx context.Context, rpcURL string, settlerAddr, taskManagerAddr common.Address) (*Client, error) {
	eth, err := ethclient.DialContext(ctx, rpcURL)
	if err != nil {
		return nil, err
	}
	chainID, err := eth.ChainID(ctx)
	if err != nil {
		return nil, err
	}
	s, err := settler.NewSettler(settlerAddr, eth)
	if err != nil {
		return nil, err
	}
	tm, err := taskmanager.NewTaskManager(taskManagerAddr, eth)
	if err != nil {
		return nil, err
	}
	return &Client{eth: eth, Settler: s, TaskManager: tm, ChainID: chainID}, nil
}

// Prevrandao is the RANDAO seed for the executor draw: post-merge it is the block header's mix
// digest. Every operator reads the same value at a given referenceBlockNumber, keeping the draw in sync.
func (c *Client) Prevrandao(ctx context.Context, block uint64) ([32]byte, error) {
	h, err := c.eth.HeaderByNumber(ctx, new(big.Int).SetUint64(block))
	if err != nil {
		return [32]byte{}, err
	}
	return h.MixDigest, nil
}

// BlockNumber returns the current head, used to derive the target block for the round.
func (c *Client) BlockNumber(ctx context.Context) (uint64, error) {
	return c.eth.BlockNumber(ctx)
}
