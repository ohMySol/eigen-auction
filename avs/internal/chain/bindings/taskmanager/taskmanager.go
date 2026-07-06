// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package taskmanager

import (
	"errors"
	"math/big"
	"strings"

	ethereum "github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
)

// Reference imports to suppress errors if they are not otherwise used.
var (
	_ = errors.New
	_ = big.NewInt
	_ = strings.NewReader
	_ = ethereum.NotFound
	_ = bind.Bind
	_ = common.Big1
	_ = types.BloomLookup
	_ = event.NewSubscription
	_ = abi.ConvertType
)

// BN254G1Point is an auto generated low-level Go binding around an user-defined struct.
type BN254G1Point struct {
	X *big.Int
	Y *big.Int
}

// BN254G2Point is an auto generated low-level Go binding around an user-defined struct.
type BN254G2Point struct {
	X [2]*big.Int
	Y [2]*big.Int
}

// Commitment is an auto generated low-level Go binding around an user-defined struct.
type Commitment struct {
	ResultHash       [32]byte
	HashOfNonSigners [32]byte
	Executor         common.Address
	Exists           bool
	Challenged       bool
}

// IBLSSignatureCheckerTypesNonSignerStakesAndSignature is an auto generated low-level Go binding around an user-defined struct.
type IBLSSignatureCheckerTypesNonSignerStakesAndSignature struct {
	NonSignerQuorumBitmapIndices []uint32
	NonSignerPubkeys             []BN254G1Point
	QuorumApks                   []BN254G1Point
	ApkG2                        BN254G2Point
	Sigma                        BN254G1Point
	QuorumApkIndices             []uint32
	TotalStakeIndices            []uint32
	NonSignerStakeIndices        [][]uint32
}

// IBLSSignatureCheckerTypesQuorumStakeTotals is an auto generated low-level Go binding around an user-defined struct.
type IBLSSignatureCheckerTypesQuorumStakeTotals struct {
	SignedStakeForQuorum []*big.Int
	TotalStakeForQuorum  []*big.Int
}

// ToBOrder is an auto generated low-level Go binding around an user-defined struct.
type ToBOrder struct {
	Searcher      common.Address
	PoolId        [32]byte
	ZeroForOne    bool
	UseInternal   bool
	QuantityIn    *big.Int
	QuantityOut   *big.Int
	ValidForBlock uint64
	Signature     []byte
}

// TaskManagerMetaData contains all meta data concerning the TaskManager contract.
var TaskManagerMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_registryCoordinator\",\"type\":\"address\",\"internalType\":\"contractISlashingRegistryCoordinator\"},{\"name\":\"_quorumNumbers\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_thresholdBps\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"_quorumNumber\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"_operatorSetId\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"blsApkRegistry\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIBLSApkRegistry\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"challenge\",\"inputs\":[{\"name\":\"poolId\",\"type\":\"bytes32\",\"internalType\":\"PoolId\"},{\"name\":\"targetBlock\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"committedArb\",\"type\":\"tuple\",\"internalType\":\"structToBOrder\",\"components\":[{\"name\":\"searcher\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"poolId\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"zeroForOne\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"useInternal\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"quantityIn\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"quantityOut\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"validForBlock\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"clearingPriceX128\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"intentsRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"dominantOrder\",\"type\":\"tuple\",\"internalType\":\"structToBOrder\",\"components\":[{\"name\":\"searcher\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"poolId\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"zeroForOne\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"useInternal\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"quantityIn\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"quantityOut\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"validForBlock\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"referenceBlockNumber\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"nonSignerPubkeyHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"checkSignatures\",\"inputs\":[{\"name\":\"msgHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"quorumNumbers\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"referenceBlockNumber\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"params\",\"type\":\"tuple\",\"internalType\":\"structIBLSSignatureCheckerTypes.NonSignerStakesAndSignature\",\"components\":[{\"name\":\"nonSignerQuorumBitmapIndices\",\"type\":\"uint32[]\",\"internalType\":\"uint32[]\"},{\"name\":\"nonSignerPubkeys\",\"type\":\"tuple[]\",\"internalType\":\"structBN254.G1Point[]\",\"components\":[{\"name\":\"X\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"Y\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"name\":\"quorumApks\",\"type\":\"tuple[]\",\"internalType\":\"structBN254.G1Point[]\",\"components\":[{\"name\":\"X\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"Y\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"name\":\"apkG2\",\"type\":\"tuple\",\"internalType\":\"structBN254.G2Point\",\"components\":[{\"name\":\"X\",\"type\":\"uint256[2]\",\"internalType\":\"uint256[2]\"},{\"name\":\"Y\",\"type\":\"uint256[2]\",\"internalType\":\"uint256[2]\"}]},{\"name\":\"sigma\",\"type\":\"tuple\",\"internalType\":\"structBN254.G1Point\",\"components\":[{\"name\":\"X\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"Y\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"name\":\"quorumApkIndices\",\"type\":\"uint32[]\",\"internalType\":\"uint32[]\"},{\"name\":\"totalStakeIndices\",\"type\":\"uint32[]\",\"internalType\":\"uint32[]\"},{\"name\":\"nonSignerStakeIndices\",\"type\":\"uint32[][]\",\"internalType\":\"uint32[][]\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structIBLSSignatureCheckerTypes.QuorumStakeTotals\",\"components\":[{\"name\":\"signedStakeForQuorum\",\"type\":\"uint96[]\",\"internalType\":\"uint96[]\"},{\"name\":\"totalStakeForQuorum\",\"type\":\"uint96[]\",\"internalType\":\"uint96[]\"}]},{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"commitWinner\",\"inputs\":[{\"name\":\"poolId\",\"type\":\"bytes32\",\"internalType\":\"PoolId\"},{\"name\":\"targetBlock\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"resultHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"executor\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"referenceBlockNumber\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"quorums\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"nonSignerStakesAndSignature\",\"type\":\"tuple\",\"internalType\":\"structIBLSSignatureCheckerTypes.NonSignerStakesAndSignature\",\"components\":[{\"name\":\"nonSignerQuorumBitmapIndices\",\"type\":\"uint32[]\",\"internalType\":\"uint32[]\"},{\"name\":\"nonSignerPubkeys\",\"type\":\"tuple[]\",\"internalType\":\"structBN254.G1Point[]\",\"components\":[{\"name\":\"X\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"Y\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"name\":\"quorumApks\",\"type\":\"tuple[]\",\"internalType\":\"structBN254.G1Point[]\",\"components\":[{\"name\":\"X\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"Y\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"name\":\"apkG2\",\"type\":\"tuple\",\"internalType\":\"structBN254.G2Point\",\"components\":[{\"name\":\"X\",\"type\":\"uint256[2]\",\"internalType\":\"uint256[2]\"},{\"name\":\"Y\",\"type\":\"uint256[2]\",\"internalType\":\"uint256[2]\"}]},{\"name\":\"sigma\",\"type\":\"tuple\",\"internalType\":\"structBN254.G1Point\",\"components\":[{\"name\":\"X\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"Y\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"name\":\"quorumApkIndices\",\"type\":\"uint32[]\",\"internalType\":\"uint32[]\"},{\"name\":\"totalStakeIndices\",\"type\":\"uint32[]\",\"internalType\":\"uint32[]\"},{\"name\":\"nonSignerStakeIndices\",\"type\":\"uint32[][]\",\"internalType\":\"uint32[][]\"}]}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"delegation\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIDelegationManager\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getCommitment\",\"inputs\":[{\"name\":\"poolId\",\"type\":\"bytes32\",\"internalType\":\"PoolId\"},{\"name\":\"targetBlock\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structCommitment\",\"components\":[{\"name\":\"resultHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"hashOfNonSigners\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"executor\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"exists\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"challenged\",\"type\":\"bool\",\"internalType\":\"bool\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"indexRegistry\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIIndexRegistry\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"operatorSetId\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"quorumNumber\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"quorumNumbers\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"registryCoordinator\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISlashingRegistryCoordinator\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"setQuorumNumbers\",\"inputs\":[{\"name\":\"newQuorumNumbers\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setSettler\",\"inputs\":[{\"name\":\"newSettler\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setSlashingConfig\",\"inputs\":[{\"name\":\"newStrategies\",\"type\":\"address[]\",\"internalType\":\"contractIStrategy[]\"},{\"name\":\"newWadToSlash\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setThreshold\",\"inputs\":[{\"name\":\"newThresholdBps\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setVetoableSlasher\",\"inputs\":[{\"name\":\"newVetoableSlasher\",\"type\":\"address\",\"internalType\":\"contractIVetoableSlasher\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"settler\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"stakeRegistry\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIStakeRegistry\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"strategies\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"contractIStrategy[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"thresholdBps\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"trySignatureAndApkVerification\",\"inputs\":[{\"name\":\"msgHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"apk\",\"type\":\"tuple\",\"internalType\":\"structBN254.G1Point\",\"components\":[{\"name\":\"X\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"Y\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"name\":\"apkG2\",\"type\":\"tuple\",\"internalType\":\"structBN254.G2Point\",\"components\":[{\"name\":\"X\",\"type\":\"uint256[2]\",\"internalType\":\"uint256[2]\"},{\"name\":\"Y\",\"type\":\"uint256[2]\",\"internalType\":\"uint256[2]\"}]},{\"name\":\"sigma\",\"type\":\"tuple\",\"internalType\":\"structBN254.G1Point\",\"components\":[{\"name\":\"X\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"Y\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]}],\"outputs\":[{\"name\":\"pairingSuccessful\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"siganatureIsValid\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"vetoableSlasher\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIVetoableSlasher\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"wadToSlash\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"CommitmentChallenged\",\"inputs\":[{\"name\":\"poolId\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"PoolId\"},{\"name\":\"targetBlock\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"challenger\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OperatorSlashQueued\",\"inputs\":[{\"name\":\"operator\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SignatorySlashingQueued\",\"inputs\":[{\"name\":\"poolId\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"PoolId\"},{\"name\":\"targetBlock\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"signerCount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SlashingConfigSet\",\"inputs\":[{\"name\":\"strategyCount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"wadToSlash\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"WinnerCommitted\",\"inputs\":[{\"name\":\"poolId\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"PoolId\"},{\"name\":\"targetBlock\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"executor\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"resultHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"BitmapValueTooLarge\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BytesArrayLengthTooLong\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BytesArrayNotOrdered\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ECAddFailed\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ECMulFailed\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EigenAuctionTaskManager_AlreadyChallenged\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EigenAuctionTaskManager_AlreadyCommitted\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EigenAuctionTaskManager_ChallengeWindowClosed\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EigenAuctionTaskManager_EmptyQuorumNumbers\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EigenAuctionTaskManager_FutureReferenceBlock\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EigenAuctionTaskManager_InvalidOrderSignature\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EigenAuctionTaskManager_InvalidSlashingConfig\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EigenAuctionTaskManager_InvalidThreshold\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EigenAuctionTaskManager_NoCommitment\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EigenAuctionTaskManager_NotDominant\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EigenAuctionTaskManager_OrderMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EigenAuctionTaskManager_QuorumNotMet\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EigenAuctionTaskManager_QuorumNumbersMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EigenAuctionTaskManager_ResultMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EigenAuctionTaskManager_SignatoryRecordMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EigenAuctionTaskManager_WrongTargetBlock\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EigenAuctionTaskManager_ZeroExecutor\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ExpModFailed\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InputArrayLengthMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InputEmptyQuorumNumbers\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InputNonSignerLengthMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidBLSPairingKey\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidBLSSignature\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidQuorumApkHash\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidReferenceBlocknumber\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NonSignerPubkeysNotSorted\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"OnlyRegistryCoordinatorOwner\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ScalarTooLarge\",\"inputs\":[]}]",
}

// TaskManagerABI is the input ABI used to generate the binding from.
// Deprecated: Use TaskManagerMetaData.ABI instead.
var TaskManagerABI = TaskManagerMetaData.ABI

// TaskManager is an auto generated Go binding around an Ethereum contract.
type TaskManager struct {
	TaskManagerCaller     // Read-only binding to the contract
	TaskManagerTransactor // Write-only binding to the contract
	TaskManagerFilterer   // Log filterer for contract events
}

// TaskManagerCaller is an auto generated read-only Go binding around an Ethereum contract.
type TaskManagerCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaskManagerTransactor is an auto generated write-only Go binding around an Ethereum contract.
type TaskManagerTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaskManagerFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type TaskManagerFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaskManagerSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type TaskManagerSession struct {
	Contract     *TaskManager      // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// TaskManagerCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type TaskManagerCallerSession struct {
	Contract *TaskManagerCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts      // Call options to use throughout this session
}

// TaskManagerTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type TaskManagerTransactorSession struct {
	Contract     *TaskManagerTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// TaskManagerRaw is an auto generated low-level Go binding around an Ethereum contract.
type TaskManagerRaw struct {
	Contract *TaskManager // Generic contract binding to access the raw methods on
}

// TaskManagerCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type TaskManagerCallerRaw struct {
	Contract *TaskManagerCaller // Generic read-only contract binding to access the raw methods on
}

// TaskManagerTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type TaskManagerTransactorRaw struct {
	Contract *TaskManagerTransactor // Generic write-only contract binding to access the raw methods on
}

// NewTaskManager creates a new instance of TaskManager, bound to a specific deployed contract.
func NewTaskManager(address common.Address, backend bind.ContractBackend) (*TaskManager, error) {
	contract, err := bindTaskManager(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &TaskManager{TaskManagerCaller: TaskManagerCaller{contract: contract}, TaskManagerTransactor: TaskManagerTransactor{contract: contract}, TaskManagerFilterer: TaskManagerFilterer{contract: contract}}, nil
}

// NewTaskManagerCaller creates a new read-only instance of TaskManager, bound to a specific deployed contract.
func NewTaskManagerCaller(address common.Address, caller bind.ContractCaller) (*TaskManagerCaller, error) {
	contract, err := bindTaskManager(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &TaskManagerCaller{contract: contract}, nil
}

// NewTaskManagerTransactor creates a new write-only instance of TaskManager, bound to a specific deployed contract.
func NewTaskManagerTransactor(address common.Address, transactor bind.ContractTransactor) (*TaskManagerTransactor, error) {
	contract, err := bindTaskManager(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &TaskManagerTransactor{contract: contract}, nil
}

// NewTaskManagerFilterer creates a new log filterer instance of TaskManager, bound to a specific deployed contract.
func NewTaskManagerFilterer(address common.Address, filterer bind.ContractFilterer) (*TaskManagerFilterer, error) {
	contract, err := bindTaskManager(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &TaskManagerFilterer{contract: contract}, nil
}

// bindTaskManager binds a generic wrapper to an already deployed contract.
func bindTaskManager(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := TaskManagerMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaskManager *TaskManagerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaskManager.Contract.TaskManagerCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaskManager *TaskManagerRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaskManager.Contract.TaskManagerTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaskManager *TaskManagerRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaskManager.Contract.TaskManagerTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaskManager *TaskManagerCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaskManager.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaskManager *TaskManagerTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaskManager.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaskManager *TaskManagerTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaskManager.Contract.contract.Transact(opts, method, params...)
}

// BlsApkRegistry is a free data retrieval call binding the contract method 0x5df45946.
//
// Solidity: function blsApkRegistry() view returns(address)
func (_TaskManager *TaskManagerCaller) BlsApkRegistry(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaskManager.contract.Call(opts, &out, "blsApkRegistry")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// BlsApkRegistry is a free data retrieval call binding the contract method 0x5df45946.
//
// Solidity: function blsApkRegistry() view returns(address)
func (_TaskManager *TaskManagerSession) BlsApkRegistry() (common.Address, error) {
	return _TaskManager.Contract.BlsApkRegistry(&_TaskManager.CallOpts)
}

// BlsApkRegistry is a free data retrieval call binding the contract method 0x5df45946.
//
// Solidity: function blsApkRegistry() view returns(address)
func (_TaskManager *TaskManagerCallerSession) BlsApkRegistry() (common.Address, error) {
	return _TaskManager.Contract.BlsApkRegistry(&_TaskManager.CallOpts)
}

// CheckSignatures is a free data retrieval call binding the contract method 0x6efb4636.
//
// Solidity: function checkSignatures(bytes32 msgHash, bytes quorumNumbers, uint32 referenceBlockNumber, (uint32[],(uint256,uint256)[],(uint256,uint256)[],(uint256[2],uint256[2]),(uint256,uint256),uint32[],uint32[],uint32[][]) params) view returns((uint96[],uint96[]), bytes32)
func (_TaskManager *TaskManagerCaller) CheckSignatures(opts *bind.CallOpts, msgHash [32]byte, quorumNumbers []byte, referenceBlockNumber uint32, params IBLSSignatureCheckerTypesNonSignerStakesAndSignature) (IBLSSignatureCheckerTypesQuorumStakeTotals, [32]byte, error) {
	var out []interface{}
	err := _TaskManager.contract.Call(opts, &out, "checkSignatures", msgHash, quorumNumbers, referenceBlockNumber, params)

	if err != nil {
		return *new(IBLSSignatureCheckerTypesQuorumStakeTotals), *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new(IBLSSignatureCheckerTypesQuorumStakeTotals)).(*IBLSSignatureCheckerTypesQuorumStakeTotals)
	out1 := *abi.ConvertType(out[1], new([32]byte)).(*[32]byte)

	return out0, out1, err

}

// CheckSignatures is a free data retrieval call binding the contract method 0x6efb4636.
//
// Solidity: function checkSignatures(bytes32 msgHash, bytes quorumNumbers, uint32 referenceBlockNumber, (uint32[],(uint256,uint256)[],(uint256,uint256)[],(uint256[2],uint256[2]),(uint256,uint256),uint32[],uint32[],uint32[][]) params) view returns((uint96[],uint96[]), bytes32)
func (_TaskManager *TaskManagerSession) CheckSignatures(msgHash [32]byte, quorumNumbers []byte, referenceBlockNumber uint32, params IBLSSignatureCheckerTypesNonSignerStakesAndSignature) (IBLSSignatureCheckerTypesQuorumStakeTotals, [32]byte, error) {
	return _TaskManager.Contract.CheckSignatures(&_TaskManager.CallOpts, msgHash, quorumNumbers, referenceBlockNumber, params)
}

// CheckSignatures is a free data retrieval call binding the contract method 0x6efb4636.
//
// Solidity: function checkSignatures(bytes32 msgHash, bytes quorumNumbers, uint32 referenceBlockNumber, (uint32[],(uint256,uint256)[],(uint256,uint256)[],(uint256[2],uint256[2]),(uint256,uint256),uint32[],uint32[],uint32[][]) params) view returns((uint96[],uint96[]), bytes32)
func (_TaskManager *TaskManagerCallerSession) CheckSignatures(msgHash [32]byte, quorumNumbers []byte, referenceBlockNumber uint32, params IBLSSignatureCheckerTypesNonSignerStakesAndSignature) (IBLSSignatureCheckerTypesQuorumStakeTotals, [32]byte, error) {
	return _TaskManager.Contract.CheckSignatures(&_TaskManager.CallOpts, msgHash, quorumNumbers, referenceBlockNumber, params)
}

// Delegation is a free data retrieval call binding the contract method 0xdf5cf723.
//
// Solidity: function delegation() view returns(address)
func (_TaskManager *TaskManagerCaller) Delegation(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaskManager.contract.Call(opts, &out, "delegation")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Delegation is a free data retrieval call binding the contract method 0xdf5cf723.
//
// Solidity: function delegation() view returns(address)
func (_TaskManager *TaskManagerSession) Delegation() (common.Address, error) {
	return _TaskManager.Contract.Delegation(&_TaskManager.CallOpts)
}

// Delegation is a free data retrieval call binding the contract method 0xdf5cf723.
//
// Solidity: function delegation() view returns(address)
func (_TaskManager *TaskManagerCallerSession) Delegation() (common.Address, error) {
	return _TaskManager.Contract.Delegation(&_TaskManager.CallOpts)
}

// GetCommitment is a free data retrieval call binding the contract method 0x10962dc8.
//
// Solidity: function getCommitment(bytes32 poolId, uint256 targetBlock) view returns((bytes32,bytes32,address,bool,bool))
func (_TaskManager *TaskManagerCaller) GetCommitment(opts *bind.CallOpts, poolId [32]byte, targetBlock *big.Int) (Commitment, error) {
	var out []interface{}
	err := _TaskManager.contract.Call(opts, &out, "getCommitment", poolId, targetBlock)

	if err != nil {
		return *new(Commitment), err
	}

	out0 := *abi.ConvertType(out[0], new(Commitment)).(*Commitment)

	return out0, err

}

// GetCommitment is a free data retrieval call binding the contract method 0x10962dc8.
//
// Solidity: function getCommitment(bytes32 poolId, uint256 targetBlock) view returns((bytes32,bytes32,address,bool,bool))
func (_TaskManager *TaskManagerSession) GetCommitment(poolId [32]byte, targetBlock *big.Int) (Commitment, error) {
	return _TaskManager.Contract.GetCommitment(&_TaskManager.CallOpts, poolId, targetBlock)
}

// GetCommitment is a free data retrieval call binding the contract method 0x10962dc8.
//
// Solidity: function getCommitment(bytes32 poolId, uint256 targetBlock) view returns((bytes32,bytes32,address,bool,bool))
func (_TaskManager *TaskManagerCallerSession) GetCommitment(poolId [32]byte, targetBlock *big.Int) (Commitment, error) {
	return _TaskManager.Contract.GetCommitment(&_TaskManager.CallOpts, poolId, targetBlock)
}

// IndexRegistry is a free data retrieval call binding the contract method 0x9e9923c2.
//
// Solidity: function indexRegistry() view returns(address)
func (_TaskManager *TaskManagerCaller) IndexRegistry(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaskManager.contract.Call(opts, &out, "indexRegistry")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// IndexRegistry is a free data retrieval call binding the contract method 0x9e9923c2.
//
// Solidity: function indexRegistry() view returns(address)
func (_TaskManager *TaskManagerSession) IndexRegistry() (common.Address, error) {
	return _TaskManager.Contract.IndexRegistry(&_TaskManager.CallOpts)
}

// IndexRegistry is a free data retrieval call binding the contract method 0x9e9923c2.
//
// Solidity: function indexRegistry() view returns(address)
func (_TaskManager *TaskManagerCallerSession) IndexRegistry() (common.Address, error) {
	return _TaskManager.Contract.IndexRegistry(&_TaskManager.CallOpts)
}

// OperatorSetId is a free data retrieval call binding the contract method 0xe1ebfc37.
//
// Solidity: function operatorSetId() view returns(uint32)
func (_TaskManager *TaskManagerCaller) OperatorSetId(opts *bind.CallOpts) (uint32, error) {
	var out []interface{}
	err := _TaskManager.contract.Call(opts, &out, "operatorSetId")

	if err != nil {
		return *new(uint32), err
	}

	out0 := *abi.ConvertType(out[0], new(uint32)).(*uint32)

	return out0, err

}

// OperatorSetId is a free data retrieval call binding the contract method 0xe1ebfc37.
//
// Solidity: function operatorSetId() view returns(uint32)
func (_TaskManager *TaskManagerSession) OperatorSetId() (uint32, error) {
	return _TaskManager.Contract.OperatorSetId(&_TaskManager.CallOpts)
}

// OperatorSetId is a free data retrieval call binding the contract method 0xe1ebfc37.
//
// Solidity: function operatorSetId() view returns(uint32)
func (_TaskManager *TaskManagerCallerSession) OperatorSetId() (uint32, error) {
	return _TaskManager.Contract.OperatorSetId(&_TaskManager.CallOpts)
}

// QuorumNumber is a free data retrieval call binding the contract method 0xcdf80e81.
//
// Solidity: function quorumNumber() view returns(uint8)
func (_TaskManager *TaskManagerCaller) QuorumNumber(opts *bind.CallOpts) (uint8, error) {
	var out []interface{}
	err := _TaskManager.contract.Call(opts, &out, "quorumNumber")

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// QuorumNumber is a free data retrieval call binding the contract method 0xcdf80e81.
//
// Solidity: function quorumNumber() view returns(uint8)
func (_TaskManager *TaskManagerSession) QuorumNumber() (uint8, error) {
	return _TaskManager.Contract.QuorumNumber(&_TaskManager.CallOpts)
}

// QuorumNumber is a free data retrieval call binding the contract method 0xcdf80e81.
//
// Solidity: function quorumNumber() view returns(uint8)
func (_TaskManager *TaskManagerCallerSession) QuorumNumber() (uint8, error) {
	return _TaskManager.Contract.QuorumNumber(&_TaskManager.CallOpts)
}

// QuorumNumbers is a free data retrieval call binding the contract method 0x2a8414fd.
//
// Solidity: function quorumNumbers() view returns(bytes)
func (_TaskManager *TaskManagerCaller) QuorumNumbers(opts *bind.CallOpts) ([]byte, error) {
	var out []interface{}
	err := _TaskManager.contract.Call(opts, &out, "quorumNumbers")

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// QuorumNumbers is a free data retrieval call binding the contract method 0x2a8414fd.
//
// Solidity: function quorumNumbers() view returns(bytes)
func (_TaskManager *TaskManagerSession) QuorumNumbers() ([]byte, error) {
	return _TaskManager.Contract.QuorumNumbers(&_TaskManager.CallOpts)
}

// QuorumNumbers is a free data retrieval call binding the contract method 0x2a8414fd.
//
// Solidity: function quorumNumbers() view returns(bytes)
func (_TaskManager *TaskManagerCallerSession) QuorumNumbers() ([]byte, error) {
	return _TaskManager.Contract.QuorumNumbers(&_TaskManager.CallOpts)
}

// RegistryCoordinator is a free data retrieval call binding the contract method 0x6d14a987.
//
// Solidity: function registryCoordinator() view returns(address)
func (_TaskManager *TaskManagerCaller) RegistryCoordinator(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaskManager.contract.Call(opts, &out, "registryCoordinator")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// RegistryCoordinator is a free data retrieval call binding the contract method 0x6d14a987.
//
// Solidity: function registryCoordinator() view returns(address)
func (_TaskManager *TaskManagerSession) RegistryCoordinator() (common.Address, error) {
	return _TaskManager.Contract.RegistryCoordinator(&_TaskManager.CallOpts)
}

// RegistryCoordinator is a free data retrieval call binding the contract method 0x6d14a987.
//
// Solidity: function registryCoordinator() view returns(address)
func (_TaskManager *TaskManagerCallerSession) RegistryCoordinator() (common.Address, error) {
	return _TaskManager.Contract.RegistryCoordinator(&_TaskManager.CallOpts)
}

// Settler is a free data retrieval call binding the contract method 0xab221a76.
//
// Solidity: function settler() view returns(address)
func (_TaskManager *TaskManagerCaller) Settler(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaskManager.contract.Call(opts, &out, "settler")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Settler is a free data retrieval call binding the contract method 0xab221a76.
//
// Solidity: function settler() view returns(address)
func (_TaskManager *TaskManagerSession) Settler() (common.Address, error) {
	return _TaskManager.Contract.Settler(&_TaskManager.CallOpts)
}

// Settler is a free data retrieval call binding the contract method 0xab221a76.
//
// Solidity: function settler() view returns(address)
func (_TaskManager *TaskManagerCallerSession) Settler() (common.Address, error) {
	return _TaskManager.Contract.Settler(&_TaskManager.CallOpts)
}

// StakeRegistry is a free data retrieval call binding the contract method 0x68304835.
//
// Solidity: function stakeRegistry() view returns(address)
func (_TaskManager *TaskManagerCaller) StakeRegistry(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaskManager.contract.Call(opts, &out, "stakeRegistry")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// StakeRegistry is a free data retrieval call binding the contract method 0x68304835.
//
// Solidity: function stakeRegistry() view returns(address)
func (_TaskManager *TaskManagerSession) StakeRegistry() (common.Address, error) {
	return _TaskManager.Contract.StakeRegistry(&_TaskManager.CallOpts)
}

// StakeRegistry is a free data retrieval call binding the contract method 0x68304835.
//
// Solidity: function stakeRegistry() view returns(address)
func (_TaskManager *TaskManagerCallerSession) StakeRegistry() (common.Address, error) {
	return _TaskManager.Contract.StakeRegistry(&_TaskManager.CallOpts)
}

// Strategies is a free data retrieval call binding the contract method 0xd9f9027f.
//
// Solidity: function strategies() view returns(address[])
func (_TaskManager *TaskManagerCaller) Strategies(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _TaskManager.contract.Call(opts, &out, "strategies")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// Strategies is a free data retrieval call binding the contract method 0xd9f9027f.
//
// Solidity: function strategies() view returns(address[])
func (_TaskManager *TaskManagerSession) Strategies() ([]common.Address, error) {
	return _TaskManager.Contract.Strategies(&_TaskManager.CallOpts)
}

// Strategies is a free data retrieval call binding the contract method 0xd9f9027f.
//
// Solidity: function strategies() view returns(address[])
func (_TaskManager *TaskManagerCallerSession) Strategies() ([]common.Address, error) {
	return _TaskManager.Contract.Strategies(&_TaskManager.CallOpts)
}

// ThresholdBps is a free data retrieval call binding the contract method 0xc1144b71.
//
// Solidity: function thresholdBps() view returns(uint256)
func (_TaskManager *TaskManagerCaller) ThresholdBps(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _TaskManager.contract.Call(opts, &out, "thresholdBps")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// ThresholdBps is a free data retrieval call binding the contract method 0xc1144b71.
//
// Solidity: function thresholdBps() view returns(uint256)
func (_TaskManager *TaskManagerSession) ThresholdBps() (*big.Int, error) {
	return _TaskManager.Contract.ThresholdBps(&_TaskManager.CallOpts)
}

// ThresholdBps is a free data retrieval call binding the contract method 0xc1144b71.
//
// Solidity: function thresholdBps() view returns(uint256)
func (_TaskManager *TaskManagerCallerSession) ThresholdBps() (*big.Int, error) {
	return _TaskManager.Contract.ThresholdBps(&_TaskManager.CallOpts)
}

// TrySignatureAndApkVerification is a free data retrieval call binding the contract method 0x171f1d5b.
//
// Solidity: function trySignatureAndApkVerification(bytes32 msgHash, (uint256,uint256) apk, (uint256[2],uint256[2]) apkG2, (uint256,uint256) sigma) view returns(bool pairingSuccessful, bool siganatureIsValid)
func (_TaskManager *TaskManagerCaller) TrySignatureAndApkVerification(opts *bind.CallOpts, msgHash [32]byte, apk BN254G1Point, apkG2 BN254G2Point, sigma BN254G1Point) (struct {
	PairingSuccessful bool
	SiganatureIsValid bool
}, error) {
	var out []interface{}
	err := _TaskManager.contract.Call(opts, &out, "trySignatureAndApkVerification", msgHash, apk, apkG2, sigma)

	outstruct := new(struct {
		PairingSuccessful bool
		SiganatureIsValid bool
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.PairingSuccessful = *abi.ConvertType(out[0], new(bool)).(*bool)
	outstruct.SiganatureIsValid = *abi.ConvertType(out[1], new(bool)).(*bool)

	return *outstruct, err

}

// TrySignatureAndApkVerification is a free data retrieval call binding the contract method 0x171f1d5b.
//
// Solidity: function trySignatureAndApkVerification(bytes32 msgHash, (uint256,uint256) apk, (uint256[2],uint256[2]) apkG2, (uint256,uint256) sigma) view returns(bool pairingSuccessful, bool siganatureIsValid)
func (_TaskManager *TaskManagerSession) TrySignatureAndApkVerification(msgHash [32]byte, apk BN254G1Point, apkG2 BN254G2Point, sigma BN254G1Point) (struct {
	PairingSuccessful bool
	SiganatureIsValid bool
}, error) {
	return _TaskManager.Contract.TrySignatureAndApkVerification(&_TaskManager.CallOpts, msgHash, apk, apkG2, sigma)
}

// TrySignatureAndApkVerification is a free data retrieval call binding the contract method 0x171f1d5b.
//
// Solidity: function trySignatureAndApkVerification(bytes32 msgHash, (uint256,uint256) apk, (uint256[2],uint256[2]) apkG2, (uint256,uint256) sigma) view returns(bool pairingSuccessful, bool siganatureIsValid)
func (_TaskManager *TaskManagerCallerSession) TrySignatureAndApkVerification(msgHash [32]byte, apk BN254G1Point, apkG2 BN254G2Point, sigma BN254G1Point) (struct {
	PairingSuccessful bool
	SiganatureIsValid bool
}, error) {
	return _TaskManager.Contract.TrySignatureAndApkVerification(&_TaskManager.CallOpts, msgHash, apk, apkG2, sigma)
}

// VetoableSlasher is a free data retrieval call binding the contract method 0xb7d79c93.
//
// Solidity: function vetoableSlasher() view returns(address)
func (_TaskManager *TaskManagerCaller) VetoableSlasher(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaskManager.contract.Call(opts, &out, "vetoableSlasher")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// VetoableSlasher is a free data retrieval call binding the contract method 0xb7d79c93.
//
// Solidity: function vetoableSlasher() view returns(address)
func (_TaskManager *TaskManagerSession) VetoableSlasher() (common.Address, error) {
	return _TaskManager.Contract.VetoableSlasher(&_TaskManager.CallOpts)
}

// VetoableSlasher is a free data retrieval call binding the contract method 0xb7d79c93.
//
// Solidity: function vetoableSlasher() view returns(address)
func (_TaskManager *TaskManagerCallerSession) VetoableSlasher() (common.Address, error) {
	return _TaskManager.Contract.VetoableSlasher(&_TaskManager.CallOpts)
}

// WadToSlash is a free data retrieval call binding the contract method 0xc897c601.
//
// Solidity: function wadToSlash() view returns(uint256)
func (_TaskManager *TaskManagerCaller) WadToSlash(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _TaskManager.contract.Call(opts, &out, "wadToSlash")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// WadToSlash is a free data retrieval call binding the contract method 0xc897c601.
//
// Solidity: function wadToSlash() view returns(uint256)
func (_TaskManager *TaskManagerSession) WadToSlash() (*big.Int, error) {
	return _TaskManager.Contract.WadToSlash(&_TaskManager.CallOpts)
}

// WadToSlash is a free data retrieval call binding the contract method 0xc897c601.
//
// Solidity: function wadToSlash() view returns(uint256)
func (_TaskManager *TaskManagerCallerSession) WadToSlash() (*big.Int, error) {
	return _TaskManager.Contract.WadToSlash(&_TaskManager.CallOpts)
}

// Challenge is a paid mutator transaction binding the contract method 0xe5b1afdc.
//
// Solidity: function challenge(bytes32 poolId, uint256 targetBlock, (address,bytes32,bool,bool,uint128,uint128,uint64,bytes) committedArb, uint256 clearingPriceX128, bytes32 intentsRoot, (address,bytes32,bool,bool,uint128,uint128,uint64,bytes) dominantOrder, uint32 referenceBlockNumber, bytes32[] nonSignerPubkeyHashes) returns()
func (_TaskManager *TaskManagerTransactor) Challenge(opts *bind.TransactOpts, poolId [32]byte, targetBlock *big.Int, committedArb ToBOrder, clearingPriceX128 *big.Int, intentsRoot [32]byte, dominantOrder ToBOrder, referenceBlockNumber uint32, nonSignerPubkeyHashes [][32]byte) (*types.Transaction, error) {
	return _TaskManager.contract.Transact(opts, "challenge", poolId, targetBlock, committedArb, clearingPriceX128, intentsRoot, dominantOrder, referenceBlockNumber, nonSignerPubkeyHashes)
}

// Challenge is a paid mutator transaction binding the contract method 0xe5b1afdc.
//
// Solidity: function challenge(bytes32 poolId, uint256 targetBlock, (address,bytes32,bool,bool,uint128,uint128,uint64,bytes) committedArb, uint256 clearingPriceX128, bytes32 intentsRoot, (address,bytes32,bool,bool,uint128,uint128,uint64,bytes) dominantOrder, uint32 referenceBlockNumber, bytes32[] nonSignerPubkeyHashes) returns()
func (_TaskManager *TaskManagerSession) Challenge(poolId [32]byte, targetBlock *big.Int, committedArb ToBOrder, clearingPriceX128 *big.Int, intentsRoot [32]byte, dominantOrder ToBOrder, referenceBlockNumber uint32, nonSignerPubkeyHashes [][32]byte) (*types.Transaction, error) {
	return _TaskManager.Contract.Challenge(&_TaskManager.TransactOpts, poolId, targetBlock, committedArb, clearingPriceX128, intentsRoot, dominantOrder, referenceBlockNumber, nonSignerPubkeyHashes)
}

// Challenge is a paid mutator transaction binding the contract method 0xe5b1afdc.
//
// Solidity: function challenge(bytes32 poolId, uint256 targetBlock, (address,bytes32,bool,bool,uint128,uint128,uint64,bytes) committedArb, uint256 clearingPriceX128, bytes32 intentsRoot, (address,bytes32,bool,bool,uint128,uint128,uint64,bytes) dominantOrder, uint32 referenceBlockNumber, bytes32[] nonSignerPubkeyHashes) returns()
func (_TaskManager *TaskManagerTransactorSession) Challenge(poolId [32]byte, targetBlock *big.Int, committedArb ToBOrder, clearingPriceX128 *big.Int, intentsRoot [32]byte, dominantOrder ToBOrder, referenceBlockNumber uint32, nonSignerPubkeyHashes [][32]byte) (*types.Transaction, error) {
	return _TaskManager.Contract.Challenge(&_TaskManager.TransactOpts, poolId, targetBlock, committedArb, clearingPriceX128, intentsRoot, dominantOrder, referenceBlockNumber, nonSignerPubkeyHashes)
}

// CommitWinner is a paid mutator transaction binding the contract method 0xffbab712.
//
// Solidity: function commitWinner(bytes32 poolId, uint256 targetBlock, bytes32 resultHash, address executor, uint32 referenceBlockNumber, bytes quorums, (uint32[],(uint256,uint256)[],(uint256,uint256)[],(uint256[2],uint256[2]),(uint256,uint256),uint32[],uint32[],uint32[][]) nonSignerStakesAndSignature) returns()
func (_TaskManager *TaskManagerTransactor) CommitWinner(opts *bind.TransactOpts, poolId [32]byte, targetBlock *big.Int, resultHash [32]byte, executor common.Address, referenceBlockNumber uint32, quorums []byte, nonSignerStakesAndSignature IBLSSignatureCheckerTypesNonSignerStakesAndSignature) (*types.Transaction, error) {
	return _TaskManager.contract.Transact(opts, "commitWinner", poolId, targetBlock, resultHash, executor, referenceBlockNumber, quorums, nonSignerStakesAndSignature)
}

// CommitWinner is a paid mutator transaction binding the contract method 0xffbab712.
//
// Solidity: function commitWinner(bytes32 poolId, uint256 targetBlock, bytes32 resultHash, address executor, uint32 referenceBlockNumber, bytes quorums, (uint32[],(uint256,uint256)[],(uint256,uint256)[],(uint256[2],uint256[2]),(uint256,uint256),uint32[],uint32[],uint32[][]) nonSignerStakesAndSignature) returns()
func (_TaskManager *TaskManagerSession) CommitWinner(poolId [32]byte, targetBlock *big.Int, resultHash [32]byte, executor common.Address, referenceBlockNumber uint32, quorums []byte, nonSignerStakesAndSignature IBLSSignatureCheckerTypesNonSignerStakesAndSignature) (*types.Transaction, error) {
	return _TaskManager.Contract.CommitWinner(&_TaskManager.TransactOpts, poolId, targetBlock, resultHash, executor, referenceBlockNumber, quorums, nonSignerStakesAndSignature)
}

// CommitWinner is a paid mutator transaction binding the contract method 0xffbab712.
//
// Solidity: function commitWinner(bytes32 poolId, uint256 targetBlock, bytes32 resultHash, address executor, uint32 referenceBlockNumber, bytes quorums, (uint32[],(uint256,uint256)[],(uint256,uint256)[],(uint256[2],uint256[2]),(uint256,uint256),uint32[],uint32[],uint32[][]) nonSignerStakesAndSignature) returns()
func (_TaskManager *TaskManagerTransactorSession) CommitWinner(poolId [32]byte, targetBlock *big.Int, resultHash [32]byte, executor common.Address, referenceBlockNumber uint32, quorums []byte, nonSignerStakesAndSignature IBLSSignatureCheckerTypesNonSignerStakesAndSignature) (*types.Transaction, error) {
	return _TaskManager.Contract.CommitWinner(&_TaskManager.TransactOpts, poolId, targetBlock, resultHash, executor, referenceBlockNumber, quorums, nonSignerStakesAndSignature)
}

// SetQuorumNumbers is a paid mutator transaction binding the contract method 0x3c24d1fd.
//
// Solidity: function setQuorumNumbers(bytes newQuorumNumbers) returns()
func (_TaskManager *TaskManagerTransactor) SetQuorumNumbers(opts *bind.TransactOpts, newQuorumNumbers []byte) (*types.Transaction, error) {
	return _TaskManager.contract.Transact(opts, "setQuorumNumbers", newQuorumNumbers)
}

// SetQuorumNumbers is a paid mutator transaction binding the contract method 0x3c24d1fd.
//
// Solidity: function setQuorumNumbers(bytes newQuorumNumbers) returns()
func (_TaskManager *TaskManagerSession) SetQuorumNumbers(newQuorumNumbers []byte) (*types.Transaction, error) {
	return _TaskManager.Contract.SetQuorumNumbers(&_TaskManager.TransactOpts, newQuorumNumbers)
}

// SetQuorumNumbers is a paid mutator transaction binding the contract method 0x3c24d1fd.
//
// Solidity: function setQuorumNumbers(bytes newQuorumNumbers) returns()
func (_TaskManager *TaskManagerTransactorSession) SetQuorumNumbers(newQuorumNumbers []byte) (*types.Transaction, error) {
	return _TaskManager.Contract.SetQuorumNumbers(&_TaskManager.TransactOpts, newQuorumNumbers)
}

// SetSettler is a paid mutator transaction binding the contract method 0x07f19eba.
//
// Solidity: function setSettler(address newSettler) returns()
func (_TaskManager *TaskManagerTransactor) SetSettler(opts *bind.TransactOpts, newSettler common.Address) (*types.Transaction, error) {
	return _TaskManager.contract.Transact(opts, "setSettler", newSettler)
}

// SetSettler is a paid mutator transaction binding the contract method 0x07f19eba.
//
// Solidity: function setSettler(address newSettler) returns()
func (_TaskManager *TaskManagerSession) SetSettler(newSettler common.Address) (*types.Transaction, error) {
	return _TaskManager.Contract.SetSettler(&_TaskManager.TransactOpts, newSettler)
}

// SetSettler is a paid mutator transaction binding the contract method 0x07f19eba.
//
// Solidity: function setSettler(address newSettler) returns()
func (_TaskManager *TaskManagerTransactorSession) SetSettler(newSettler common.Address) (*types.Transaction, error) {
	return _TaskManager.Contract.SetSettler(&_TaskManager.TransactOpts, newSettler)
}

// SetSlashingConfig is a paid mutator transaction binding the contract method 0x37dc9d9d.
//
// Solidity: function setSlashingConfig(address[] newStrategies, uint256 newWadToSlash) returns()
func (_TaskManager *TaskManagerTransactor) SetSlashingConfig(opts *bind.TransactOpts, newStrategies []common.Address, newWadToSlash *big.Int) (*types.Transaction, error) {
	return _TaskManager.contract.Transact(opts, "setSlashingConfig", newStrategies, newWadToSlash)
}

// SetSlashingConfig is a paid mutator transaction binding the contract method 0x37dc9d9d.
//
// Solidity: function setSlashingConfig(address[] newStrategies, uint256 newWadToSlash) returns()
func (_TaskManager *TaskManagerSession) SetSlashingConfig(newStrategies []common.Address, newWadToSlash *big.Int) (*types.Transaction, error) {
	return _TaskManager.Contract.SetSlashingConfig(&_TaskManager.TransactOpts, newStrategies, newWadToSlash)
}

// SetSlashingConfig is a paid mutator transaction binding the contract method 0x37dc9d9d.
//
// Solidity: function setSlashingConfig(address[] newStrategies, uint256 newWadToSlash) returns()
func (_TaskManager *TaskManagerTransactorSession) SetSlashingConfig(newStrategies []common.Address, newWadToSlash *big.Int) (*types.Transaction, error) {
	return _TaskManager.Contract.SetSlashingConfig(&_TaskManager.TransactOpts, newStrategies, newWadToSlash)
}

// SetThreshold is a paid mutator transaction binding the contract method 0x960bfe04.
//
// Solidity: function setThreshold(uint256 newThresholdBps) returns()
func (_TaskManager *TaskManagerTransactor) SetThreshold(opts *bind.TransactOpts, newThresholdBps *big.Int) (*types.Transaction, error) {
	return _TaskManager.contract.Transact(opts, "setThreshold", newThresholdBps)
}

// SetThreshold is a paid mutator transaction binding the contract method 0x960bfe04.
//
// Solidity: function setThreshold(uint256 newThresholdBps) returns()
func (_TaskManager *TaskManagerSession) SetThreshold(newThresholdBps *big.Int) (*types.Transaction, error) {
	return _TaskManager.Contract.SetThreshold(&_TaskManager.TransactOpts, newThresholdBps)
}

// SetThreshold is a paid mutator transaction binding the contract method 0x960bfe04.
//
// Solidity: function setThreshold(uint256 newThresholdBps) returns()
func (_TaskManager *TaskManagerTransactorSession) SetThreshold(newThresholdBps *big.Int) (*types.Transaction, error) {
	return _TaskManager.Contract.SetThreshold(&_TaskManager.TransactOpts, newThresholdBps)
}

// SetVetoableSlasher is a paid mutator transaction binding the contract method 0xb6914ee6.
//
// Solidity: function setVetoableSlasher(address newVetoableSlasher) returns()
func (_TaskManager *TaskManagerTransactor) SetVetoableSlasher(opts *bind.TransactOpts, newVetoableSlasher common.Address) (*types.Transaction, error) {
	return _TaskManager.contract.Transact(opts, "setVetoableSlasher", newVetoableSlasher)
}

// SetVetoableSlasher is a paid mutator transaction binding the contract method 0xb6914ee6.
//
// Solidity: function setVetoableSlasher(address newVetoableSlasher) returns()
func (_TaskManager *TaskManagerSession) SetVetoableSlasher(newVetoableSlasher common.Address) (*types.Transaction, error) {
	return _TaskManager.Contract.SetVetoableSlasher(&_TaskManager.TransactOpts, newVetoableSlasher)
}

// SetVetoableSlasher is a paid mutator transaction binding the contract method 0xb6914ee6.
//
// Solidity: function setVetoableSlasher(address newVetoableSlasher) returns()
func (_TaskManager *TaskManagerTransactorSession) SetVetoableSlasher(newVetoableSlasher common.Address) (*types.Transaction, error) {
	return _TaskManager.Contract.SetVetoableSlasher(&_TaskManager.TransactOpts, newVetoableSlasher)
}

// TaskManagerCommitmentChallengedIterator is returned from FilterCommitmentChallenged and is used to iterate over the raw logs and unpacked data for CommitmentChallenged events raised by the TaskManager contract.
type TaskManagerCommitmentChallengedIterator struct {
	Event *TaskManagerCommitmentChallenged // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaskManagerCommitmentChallengedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaskManagerCommitmentChallenged)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaskManagerCommitmentChallenged)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaskManagerCommitmentChallengedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaskManagerCommitmentChallengedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaskManagerCommitmentChallenged represents a CommitmentChallenged event raised by the TaskManager contract.
type TaskManagerCommitmentChallenged struct {
	PoolId      [32]byte
	TargetBlock *big.Int
	Challenger  common.Address
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterCommitmentChallenged is a free log retrieval operation binding the contract event 0xf22089cd2c6ce60f45934d1bc7fd766a4e8a4e351445905a776060dd8955e0cb.
//
// Solidity: event CommitmentChallenged(bytes32 indexed poolId, uint256 indexed targetBlock, address indexed challenger)
func (_TaskManager *TaskManagerFilterer) FilterCommitmentChallenged(opts *bind.FilterOpts, poolId [][32]byte, targetBlock []*big.Int, challenger []common.Address) (*TaskManagerCommitmentChallengedIterator, error) {

	var poolIdRule []interface{}
	for _, poolIdItem := range poolId {
		poolIdRule = append(poolIdRule, poolIdItem)
	}
	var targetBlockRule []interface{}
	for _, targetBlockItem := range targetBlock {
		targetBlockRule = append(targetBlockRule, targetBlockItem)
	}
	var challengerRule []interface{}
	for _, challengerItem := range challenger {
		challengerRule = append(challengerRule, challengerItem)
	}

	logs, sub, err := _TaskManager.contract.FilterLogs(opts, "CommitmentChallenged", poolIdRule, targetBlockRule, challengerRule)
	if err != nil {
		return nil, err
	}
	return &TaskManagerCommitmentChallengedIterator{contract: _TaskManager.contract, event: "CommitmentChallenged", logs: logs, sub: sub}, nil
}

// WatchCommitmentChallenged is a free log subscription operation binding the contract event 0xf22089cd2c6ce60f45934d1bc7fd766a4e8a4e351445905a776060dd8955e0cb.
//
// Solidity: event CommitmentChallenged(bytes32 indexed poolId, uint256 indexed targetBlock, address indexed challenger)
func (_TaskManager *TaskManagerFilterer) WatchCommitmentChallenged(opts *bind.WatchOpts, sink chan<- *TaskManagerCommitmentChallenged, poolId [][32]byte, targetBlock []*big.Int, challenger []common.Address) (event.Subscription, error) {

	var poolIdRule []interface{}
	for _, poolIdItem := range poolId {
		poolIdRule = append(poolIdRule, poolIdItem)
	}
	var targetBlockRule []interface{}
	for _, targetBlockItem := range targetBlock {
		targetBlockRule = append(targetBlockRule, targetBlockItem)
	}
	var challengerRule []interface{}
	for _, challengerItem := range challenger {
		challengerRule = append(challengerRule, challengerItem)
	}

	logs, sub, err := _TaskManager.contract.WatchLogs(opts, "CommitmentChallenged", poolIdRule, targetBlockRule, challengerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaskManagerCommitmentChallenged)
				if err := _TaskManager.contract.UnpackLog(event, "CommitmentChallenged", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseCommitmentChallenged is a log parse operation binding the contract event 0xf22089cd2c6ce60f45934d1bc7fd766a4e8a4e351445905a776060dd8955e0cb.
//
// Solidity: event CommitmentChallenged(bytes32 indexed poolId, uint256 indexed targetBlock, address indexed challenger)
func (_TaskManager *TaskManagerFilterer) ParseCommitmentChallenged(log types.Log) (*TaskManagerCommitmentChallenged, error) {
	event := new(TaskManagerCommitmentChallenged)
	if err := _TaskManager.contract.UnpackLog(event, "CommitmentChallenged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaskManagerOperatorSlashQueuedIterator is returned from FilterOperatorSlashQueued and is used to iterate over the raw logs and unpacked data for OperatorSlashQueued events raised by the TaskManager contract.
type TaskManagerOperatorSlashQueuedIterator struct {
	Event *TaskManagerOperatorSlashQueued // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaskManagerOperatorSlashQueuedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaskManagerOperatorSlashQueued)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaskManagerOperatorSlashQueued)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaskManagerOperatorSlashQueuedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaskManagerOperatorSlashQueuedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaskManagerOperatorSlashQueued represents a OperatorSlashQueued event raised by the TaskManager contract.
type TaskManagerOperatorSlashQueued struct {
	Operator common.Address
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterOperatorSlashQueued is a free log retrieval operation binding the contract event 0x309dda8e952ef96aa5c071ab408c9440adf32e05b95c5d79714bc5910a6346c9.
//
// Solidity: event OperatorSlashQueued(address indexed operator)
func (_TaskManager *TaskManagerFilterer) FilterOperatorSlashQueued(opts *bind.FilterOpts, operator []common.Address) (*TaskManagerOperatorSlashQueuedIterator, error) {

	var operatorRule []interface{}
	for _, operatorItem := range operator {
		operatorRule = append(operatorRule, operatorItem)
	}

	logs, sub, err := _TaskManager.contract.FilterLogs(opts, "OperatorSlashQueued", operatorRule)
	if err != nil {
		return nil, err
	}
	return &TaskManagerOperatorSlashQueuedIterator{contract: _TaskManager.contract, event: "OperatorSlashQueued", logs: logs, sub: sub}, nil
}

// WatchOperatorSlashQueued is a free log subscription operation binding the contract event 0x309dda8e952ef96aa5c071ab408c9440adf32e05b95c5d79714bc5910a6346c9.
//
// Solidity: event OperatorSlashQueued(address indexed operator)
func (_TaskManager *TaskManagerFilterer) WatchOperatorSlashQueued(opts *bind.WatchOpts, sink chan<- *TaskManagerOperatorSlashQueued, operator []common.Address) (event.Subscription, error) {

	var operatorRule []interface{}
	for _, operatorItem := range operator {
		operatorRule = append(operatorRule, operatorItem)
	}

	logs, sub, err := _TaskManager.contract.WatchLogs(opts, "OperatorSlashQueued", operatorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaskManagerOperatorSlashQueued)
				if err := _TaskManager.contract.UnpackLog(event, "OperatorSlashQueued", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseOperatorSlashQueued is a log parse operation binding the contract event 0x309dda8e952ef96aa5c071ab408c9440adf32e05b95c5d79714bc5910a6346c9.
//
// Solidity: event OperatorSlashQueued(address indexed operator)
func (_TaskManager *TaskManagerFilterer) ParseOperatorSlashQueued(log types.Log) (*TaskManagerOperatorSlashQueued, error) {
	event := new(TaskManagerOperatorSlashQueued)
	if err := _TaskManager.contract.UnpackLog(event, "OperatorSlashQueued", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaskManagerSignatorySlashingQueuedIterator is returned from FilterSignatorySlashingQueued and is used to iterate over the raw logs and unpacked data for SignatorySlashingQueued events raised by the TaskManager contract.
type TaskManagerSignatorySlashingQueuedIterator struct {
	Event *TaskManagerSignatorySlashingQueued // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaskManagerSignatorySlashingQueuedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaskManagerSignatorySlashingQueued)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaskManagerSignatorySlashingQueued)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaskManagerSignatorySlashingQueuedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaskManagerSignatorySlashingQueuedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaskManagerSignatorySlashingQueued represents a SignatorySlashingQueued event raised by the TaskManager contract.
type TaskManagerSignatorySlashingQueued struct {
	PoolId      [32]byte
	TargetBlock *big.Int
	SignerCount *big.Int
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterSignatorySlashingQueued is a free log retrieval operation binding the contract event 0x5b104830adf3ef91e5c978c7f8ac58db1ddd9863894449fb9b1270c6aaf386b9.
//
// Solidity: event SignatorySlashingQueued(bytes32 indexed poolId, uint256 indexed targetBlock, uint256 signerCount)
func (_TaskManager *TaskManagerFilterer) FilterSignatorySlashingQueued(opts *bind.FilterOpts, poolId [][32]byte, targetBlock []*big.Int) (*TaskManagerSignatorySlashingQueuedIterator, error) {

	var poolIdRule []interface{}
	for _, poolIdItem := range poolId {
		poolIdRule = append(poolIdRule, poolIdItem)
	}
	var targetBlockRule []interface{}
	for _, targetBlockItem := range targetBlock {
		targetBlockRule = append(targetBlockRule, targetBlockItem)
	}

	logs, sub, err := _TaskManager.contract.FilterLogs(opts, "SignatorySlashingQueued", poolIdRule, targetBlockRule)
	if err != nil {
		return nil, err
	}
	return &TaskManagerSignatorySlashingQueuedIterator{contract: _TaskManager.contract, event: "SignatorySlashingQueued", logs: logs, sub: sub}, nil
}

// WatchSignatorySlashingQueued is a free log subscription operation binding the contract event 0x5b104830adf3ef91e5c978c7f8ac58db1ddd9863894449fb9b1270c6aaf386b9.
//
// Solidity: event SignatorySlashingQueued(bytes32 indexed poolId, uint256 indexed targetBlock, uint256 signerCount)
func (_TaskManager *TaskManagerFilterer) WatchSignatorySlashingQueued(opts *bind.WatchOpts, sink chan<- *TaskManagerSignatorySlashingQueued, poolId [][32]byte, targetBlock []*big.Int) (event.Subscription, error) {

	var poolIdRule []interface{}
	for _, poolIdItem := range poolId {
		poolIdRule = append(poolIdRule, poolIdItem)
	}
	var targetBlockRule []interface{}
	for _, targetBlockItem := range targetBlock {
		targetBlockRule = append(targetBlockRule, targetBlockItem)
	}

	logs, sub, err := _TaskManager.contract.WatchLogs(opts, "SignatorySlashingQueued", poolIdRule, targetBlockRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaskManagerSignatorySlashingQueued)
				if err := _TaskManager.contract.UnpackLog(event, "SignatorySlashingQueued", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseSignatorySlashingQueued is a log parse operation binding the contract event 0x5b104830adf3ef91e5c978c7f8ac58db1ddd9863894449fb9b1270c6aaf386b9.
//
// Solidity: event SignatorySlashingQueued(bytes32 indexed poolId, uint256 indexed targetBlock, uint256 signerCount)
func (_TaskManager *TaskManagerFilterer) ParseSignatorySlashingQueued(log types.Log) (*TaskManagerSignatorySlashingQueued, error) {
	event := new(TaskManagerSignatorySlashingQueued)
	if err := _TaskManager.contract.UnpackLog(event, "SignatorySlashingQueued", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaskManagerSlashingConfigSetIterator is returned from FilterSlashingConfigSet and is used to iterate over the raw logs and unpacked data for SlashingConfigSet events raised by the TaskManager contract.
type TaskManagerSlashingConfigSetIterator struct {
	Event *TaskManagerSlashingConfigSet // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaskManagerSlashingConfigSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaskManagerSlashingConfigSet)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaskManagerSlashingConfigSet)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaskManagerSlashingConfigSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaskManagerSlashingConfigSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaskManagerSlashingConfigSet represents a SlashingConfigSet event raised by the TaskManager contract.
type TaskManagerSlashingConfigSet struct {
	StrategyCount *big.Int
	WadToSlash    *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterSlashingConfigSet is a free log retrieval operation binding the contract event 0x85d0075c480d5fe431fd53f5d88ee56648cbcbb0d5cfa099b741656712e830b9.
//
// Solidity: event SlashingConfigSet(uint256 strategyCount, uint256 wadToSlash)
func (_TaskManager *TaskManagerFilterer) FilterSlashingConfigSet(opts *bind.FilterOpts) (*TaskManagerSlashingConfigSetIterator, error) {

	logs, sub, err := _TaskManager.contract.FilterLogs(opts, "SlashingConfigSet")
	if err != nil {
		return nil, err
	}
	return &TaskManagerSlashingConfigSetIterator{contract: _TaskManager.contract, event: "SlashingConfigSet", logs: logs, sub: sub}, nil
}

// WatchSlashingConfigSet is a free log subscription operation binding the contract event 0x85d0075c480d5fe431fd53f5d88ee56648cbcbb0d5cfa099b741656712e830b9.
//
// Solidity: event SlashingConfigSet(uint256 strategyCount, uint256 wadToSlash)
func (_TaskManager *TaskManagerFilterer) WatchSlashingConfigSet(opts *bind.WatchOpts, sink chan<- *TaskManagerSlashingConfigSet) (event.Subscription, error) {

	logs, sub, err := _TaskManager.contract.WatchLogs(opts, "SlashingConfigSet")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaskManagerSlashingConfigSet)
				if err := _TaskManager.contract.UnpackLog(event, "SlashingConfigSet", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseSlashingConfigSet is a log parse operation binding the contract event 0x85d0075c480d5fe431fd53f5d88ee56648cbcbb0d5cfa099b741656712e830b9.
//
// Solidity: event SlashingConfigSet(uint256 strategyCount, uint256 wadToSlash)
func (_TaskManager *TaskManagerFilterer) ParseSlashingConfigSet(log types.Log) (*TaskManagerSlashingConfigSet, error) {
	event := new(TaskManagerSlashingConfigSet)
	if err := _TaskManager.contract.UnpackLog(event, "SlashingConfigSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaskManagerWinnerCommittedIterator is returned from FilterWinnerCommitted and is used to iterate over the raw logs and unpacked data for WinnerCommitted events raised by the TaskManager contract.
type TaskManagerWinnerCommittedIterator struct {
	Event *TaskManagerWinnerCommitted // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaskManagerWinnerCommittedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaskManagerWinnerCommitted)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaskManagerWinnerCommitted)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaskManagerWinnerCommittedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaskManagerWinnerCommittedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaskManagerWinnerCommitted represents a WinnerCommitted event raised by the TaskManager contract.
type TaskManagerWinnerCommitted struct {
	PoolId      [32]byte
	TargetBlock *big.Int
	Executor    common.Address
	ResultHash  [32]byte
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterWinnerCommitted is a free log retrieval operation binding the contract event 0x24f192d6f6510219be1c977053312ee5193fc08324d770711ffb6af9fac98a30.
//
// Solidity: event WinnerCommitted(bytes32 indexed poolId, uint256 indexed targetBlock, address indexed executor, bytes32 resultHash)
func (_TaskManager *TaskManagerFilterer) FilterWinnerCommitted(opts *bind.FilterOpts, poolId [][32]byte, targetBlock []*big.Int, executor []common.Address) (*TaskManagerWinnerCommittedIterator, error) {

	var poolIdRule []interface{}
	for _, poolIdItem := range poolId {
		poolIdRule = append(poolIdRule, poolIdItem)
	}
	var targetBlockRule []interface{}
	for _, targetBlockItem := range targetBlock {
		targetBlockRule = append(targetBlockRule, targetBlockItem)
	}
	var executorRule []interface{}
	for _, executorItem := range executor {
		executorRule = append(executorRule, executorItem)
	}

	logs, sub, err := _TaskManager.contract.FilterLogs(opts, "WinnerCommitted", poolIdRule, targetBlockRule, executorRule)
	if err != nil {
		return nil, err
	}
	return &TaskManagerWinnerCommittedIterator{contract: _TaskManager.contract, event: "WinnerCommitted", logs: logs, sub: sub}, nil
}

// WatchWinnerCommitted is a free log subscription operation binding the contract event 0x24f192d6f6510219be1c977053312ee5193fc08324d770711ffb6af9fac98a30.
//
// Solidity: event WinnerCommitted(bytes32 indexed poolId, uint256 indexed targetBlock, address indexed executor, bytes32 resultHash)
func (_TaskManager *TaskManagerFilterer) WatchWinnerCommitted(opts *bind.WatchOpts, sink chan<- *TaskManagerWinnerCommitted, poolId [][32]byte, targetBlock []*big.Int, executor []common.Address) (event.Subscription, error) {

	var poolIdRule []interface{}
	for _, poolIdItem := range poolId {
		poolIdRule = append(poolIdRule, poolIdItem)
	}
	var targetBlockRule []interface{}
	for _, targetBlockItem := range targetBlock {
		targetBlockRule = append(targetBlockRule, targetBlockItem)
	}
	var executorRule []interface{}
	for _, executorItem := range executor {
		executorRule = append(executorRule, executorItem)
	}

	logs, sub, err := _TaskManager.contract.WatchLogs(opts, "WinnerCommitted", poolIdRule, targetBlockRule, executorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaskManagerWinnerCommitted)
				if err := _TaskManager.contract.UnpackLog(event, "WinnerCommitted", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseWinnerCommitted is a log parse operation binding the contract event 0x24f192d6f6510219be1c977053312ee5193fc08324d770711ffb6af9fac98a30.
//
// Solidity: event WinnerCommitted(bytes32 indexed poolId, uint256 indexed targetBlock, address indexed executor, bytes32 resultHash)
func (_TaskManager *TaskManagerFilterer) ParseWinnerCommitted(log types.Log) (*TaskManagerWinnerCommitted, error) {
	event := new(TaskManagerWinnerCommitted)
	if err := _TaskManager.contract.UnpackLog(event, "WinnerCommitted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
