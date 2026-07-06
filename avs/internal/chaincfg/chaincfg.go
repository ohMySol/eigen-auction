// Package chaincfg loads the deployment artifact (deployments/<chainId>.json) that the deploy script
// writes — the single source of contract + EL-core addresses the operator and aggregator bind to.
// Mirrors the TS DeploymentArtifact (packages/shared/config.ts) field-for-field so both stacks read
// the identical file; common.Address/common.Hash decode straight from the JSON hex strings.
package chaincfg

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/ethereum/go-ethereum/common"
)

type Pool struct {
	Currency0 common.Address `json:"currency0"`
	Currency1 common.Address `json:"currency1"`
	Currency0Decimals uint8 `json:"currency0Decimals"`
	Currency1Decimals uint8 `json:"currency1Decimals"`
	Fee uint32 `json:"fee"`
	TickSpacing int32 `json:"tickSpacing"`
	PoolID common.Hash `json:"poolId"`
}

// Deployment is the addresses + pool config the AVS binds to. The EL-core fields (delegationManager …
// stakeStrategy) are only needed by operator-set registration (§4.5); the rest drive commit/settle.
type Deployment struct {
	ChainID uint64 `json:"chainId"`
	DeployedBlock uint64 `json:"deployedBlock"`
	PoolManager common.Address `json:"poolManager"`
	StateView common.Address `json:"stateView"`
	ServiceManager common.Address `json:"serviceManager"`
	Hook common.Address `json:"hook"`
	Settler common.Address `json:"settler"`
	TaskManager common.Address `json:"taskManager"`
	RegistryCoordinator common.Address `json:"registryCoordinator"`
	StakeRegistry common.Address `json:"stakeRegistry"`
	BLSApkRegistry common.Address `json:"blsApkRegistry"`
	OperatorStateRetriever common.Address `json:"operatorStateRetriever"`
	DelegationManager common.Address `json:"delegationManager"`
	AllocationManager common.Address `json:"allocationManager"`
	AVSDirectory common.Address `json:"avsDirectory"`
	StakeStrategy common.Address `json:"stakeStrategy"`
	QuorumNumbers uint8 `json:"quorumNumbers"`
	Pool Pool `json:"pool"`
}

// Load reads deployments/<chainID>.json from dir. Empty dir defaults to the repo-root deployments/.
func Load(dir string, chainID uint64) (*Deployment, error) {
	if dir == "" {
		dir = "deployments"
	}
	file := filepath.Join(dir, fmt.Sprintf("%d.json", chainID))
	raw, err := os.ReadFile(file)
	if err != nil {
		return nil, fmt.Errorf("read deployment %s: %w", file, err)
	}
	var d Deployment
	if err := json.Unmarshal(raw, &d); err != nil {
		return nil, fmt.Errorf("parse deployment %s: %w", file, err)
	}
	if d.ChainID != chainID {
		return nil, fmt.Errorf("deployment chainId %d != requested %d", d.ChainID, chainID)
	}
	return &d, nil
}
