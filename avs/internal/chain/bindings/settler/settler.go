// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package settler

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

// PoolKey is an auto generated low-level Go binding around an user-defined struct.
type PoolKey struct {
	Currency0   common.Address
	Currency1   common.Address
	Fee         *big.Int
	TickSpacing *big.Int
	Hooks       common.Address
}

// SwapIntent is an auto generated low-level Go binding around an user-defined struct.
type SwapIntent struct {
	User         common.Address
	PoolId       [32]byte
	ZeroForOne   bool
	UseInternal  bool
	AmountIn     *big.Int
	MinAmountOut *big.Int
	Nonce        uint64
	Deadline     uint64
	Signature    []byte
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

// SettlerMetaData contains all meta data concerning the Settler contract.
var SettlerMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_poolManager\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_avs\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_taskManager\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_operatorFeeBps\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"DOMAIN_SEPARATOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"avs\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIEigenAuctionServiceManager\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"balanceOf\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"computeResultHash\",\"inputs\":[{\"name\":\"arb\",\"type\":\"tuple\",\"internalType\":\"structToBOrder\",\"components\":[{\"name\":\"searcher\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"poolId\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"zeroForOne\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"useInternal\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"quantityIn\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"quantityOut\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"validForBlock\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"clearingPriceX128\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"intents\",\"type\":\"tuple[]\",\"internalType\":\"structSwapIntent[]\",\"components\":[{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"poolId\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"zeroForOne\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"useInternal\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"amountIn\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"minAmountOut\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"nonce\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"deadline\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"deposit\",\"inputs\":[{\"name\":\"asset\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"invalidateNonce\",\"inputs\":[{\"name\":\"nonce\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isNonceUsed\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"nonce\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"operatorFeeBps\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"poolManager\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIPoolManager\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setOperatorFeeBps\",\"inputs\":[{\"name\":\"newOperatorFeeBps\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"settle\",\"inputs\":[{\"name\":\"key\",\"type\":\"tuple\",\"internalType\":\"structPoolKey\",\"components\":[{\"name\":\"currency0\",\"type\":\"address\",\"internalType\":\"Currency\"},{\"name\":\"currency1\",\"type\":\"address\",\"internalType\":\"Currency\"},{\"name\":\"fee\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"tickSpacing\",\"type\":\"int24\",\"internalType\":\"int24\"},{\"name\":\"hooks\",\"type\":\"address\",\"internalType\":\"contractIHooks\"}]},{\"name\":\"arb\",\"type\":\"tuple\",\"internalType\":\"structToBOrder\",\"components\":[{\"name\":\"searcher\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"poolId\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"zeroForOne\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"useInternal\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"quantityIn\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"quantityOut\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"validForBlock\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"intents\",\"type\":\"tuple[]\",\"internalType\":\"structSwapIntent[]\",\"components\":[{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"poolId\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"zeroForOne\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"useInternal\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"amountIn\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"minAmountOut\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"nonce\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"deadline\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"clearingPriceX128\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"taskManager\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractICommitmentReader\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unlockCallback\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"withdraw\",\"inputs\":[{\"name\":\"asset\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"ArbFilled\",\"inputs\":[{\"name\":\"poolId\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"PoolId\"},{\"name\":\"arber\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"bid\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BlockSettled\",\"inputs\":[{\"name\":\"poolId\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"PoolId\"},{\"name\":\"blockNumber\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"operator\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Deposited\",\"inputs\":[{\"name\":\"asset\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"IntentFilled\",\"inputs\":[{\"name\":\"poolId\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"PoolId\"},{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"zeroForOne\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"},{\"name\":\"amountIn\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"amountOut\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"NonceInvalidated\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"nonce\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OperatorFeeBpsSet\",\"inputs\":[{\"name\":\"newOperatorFeeBps\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Withdrawn\",\"inputs\":[{\"name\":\"asset\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"OwnableInvalidOwner\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"OwnableUnauthorizedAccount\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"Settler_BatchInsolvent\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"Settler_ConstructorZeroAddress\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"Settler_FeeTooHigh\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"Settler_InsufficientBalance\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"Settler_IntentExpired\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"Settler_InvalidArbSignature\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"Settler_InvalidSignature\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"Settler_NegativeBid\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"Settler_NoCommitment\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"Settler_NonceUsed\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"Settler_NotExecutor\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"Settler_NotPoolManager\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"Settler_NothingToSettle\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"Settler_ResultMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"Settler_SlippageExceeded\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"Settler_WrongBlock\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"Settler_WrongPool\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"Settler_ZeroClearingPrice\",\"inputs\":[]}]",
}

// SettlerABI is the input ABI used to generate the binding from.
// Deprecated: Use SettlerMetaData.ABI instead.
var SettlerABI = SettlerMetaData.ABI

// Settler is an auto generated Go binding around an Ethereum contract.
type Settler struct {
	SettlerCaller     // Read-only binding to the contract
	SettlerTransactor // Write-only binding to the contract
	SettlerFilterer   // Log filterer for contract events
}

// SettlerCaller is an auto generated read-only Go binding around an Ethereum contract.
type SettlerCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SettlerTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SettlerTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SettlerFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SettlerFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SettlerSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SettlerSession struct {
	Contract     *Settler          // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SettlerCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SettlerCallerSession struct {
	Contract *SettlerCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts  // Call options to use throughout this session
}

// SettlerTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SettlerTransactorSession struct {
	Contract     *SettlerTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts  // Transaction auth options to use throughout this session
}

// SettlerRaw is an auto generated low-level Go binding around an Ethereum contract.
type SettlerRaw struct {
	Contract *Settler // Generic contract binding to access the raw methods on
}

// SettlerCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SettlerCallerRaw struct {
	Contract *SettlerCaller // Generic read-only contract binding to access the raw methods on
}

// SettlerTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SettlerTransactorRaw struct {
	Contract *SettlerTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSettler creates a new instance of Settler, bound to a specific deployed contract.
func NewSettler(address common.Address, backend bind.ContractBackend) (*Settler, error) {
	contract, err := bindSettler(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &Settler{SettlerCaller: SettlerCaller{contract: contract}, SettlerTransactor: SettlerTransactor{contract: contract}, SettlerFilterer: SettlerFilterer{contract: contract}}, nil
}

// NewSettlerCaller creates a new read-only instance of Settler, bound to a specific deployed contract.
func NewSettlerCaller(address common.Address, caller bind.ContractCaller) (*SettlerCaller, error) {
	contract, err := bindSettler(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SettlerCaller{contract: contract}, nil
}

// NewSettlerTransactor creates a new write-only instance of Settler, bound to a specific deployed contract.
func NewSettlerTransactor(address common.Address, transactor bind.ContractTransactor) (*SettlerTransactor, error) {
	contract, err := bindSettler(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SettlerTransactor{contract: contract}, nil
}

// NewSettlerFilterer creates a new log filterer instance of Settler, bound to a specific deployed contract.
func NewSettlerFilterer(address common.Address, filterer bind.ContractFilterer) (*SettlerFilterer, error) {
	contract, err := bindSettler(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SettlerFilterer{contract: contract}, nil
}

// bindSettler binds a generic wrapper to an already deployed contract.
func bindSettler(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SettlerMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_Settler *SettlerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _Settler.Contract.SettlerCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_Settler *SettlerRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Settler.Contract.SettlerTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_Settler *SettlerRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _Settler.Contract.SettlerTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_Settler *SettlerCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _Settler.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_Settler *SettlerTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Settler.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_Settler *SettlerTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _Settler.Contract.contract.Transact(opts, method, params...)
}

// DOMAINSEPARATOR is a free data retrieval call binding the contract method 0x3644e515.
//
// Solidity: function DOMAIN_SEPARATOR() view returns(bytes32)
func (_Settler *SettlerCaller) DOMAINSEPARATOR(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _Settler.contract.Call(opts, &out, "DOMAIN_SEPARATOR")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// DOMAINSEPARATOR is a free data retrieval call binding the contract method 0x3644e515.
//
// Solidity: function DOMAIN_SEPARATOR() view returns(bytes32)
func (_Settler *SettlerSession) DOMAINSEPARATOR() ([32]byte, error) {
	return _Settler.Contract.DOMAINSEPARATOR(&_Settler.CallOpts)
}

// DOMAINSEPARATOR is a free data retrieval call binding the contract method 0x3644e515.
//
// Solidity: function DOMAIN_SEPARATOR() view returns(bytes32)
func (_Settler *SettlerCallerSession) DOMAINSEPARATOR() ([32]byte, error) {
	return _Settler.Contract.DOMAINSEPARATOR(&_Settler.CallOpts)
}

// Avs is a free data retrieval call binding the contract method 0xde1164bb.
//
// Solidity: function avs() view returns(address)
func (_Settler *SettlerCaller) Avs(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Settler.contract.Call(opts, &out, "avs")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Avs is a free data retrieval call binding the contract method 0xde1164bb.
//
// Solidity: function avs() view returns(address)
func (_Settler *SettlerSession) Avs() (common.Address, error) {
	return _Settler.Contract.Avs(&_Settler.CallOpts)
}

// Avs is a free data retrieval call binding the contract method 0xde1164bb.
//
// Solidity: function avs() view returns(address)
func (_Settler *SettlerCallerSession) Avs() (common.Address, error) {
	return _Settler.Contract.Avs(&_Settler.CallOpts)
}

// BalanceOf is a free data retrieval call binding the contract method 0xf7888aec.
//
// Solidity: function balanceOf(address , address ) view returns(uint256)
func (_Settler *SettlerCaller) BalanceOf(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address) (*big.Int, error) {
	var out []interface{}
	err := _Settler.contract.Call(opts, &out, "balanceOf", arg0, arg1)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// BalanceOf is a free data retrieval call binding the contract method 0xf7888aec.
//
// Solidity: function balanceOf(address , address ) view returns(uint256)
func (_Settler *SettlerSession) BalanceOf(arg0 common.Address, arg1 common.Address) (*big.Int, error) {
	return _Settler.Contract.BalanceOf(&_Settler.CallOpts, arg0, arg1)
}

// BalanceOf is a free data retrieval call binding the contract method 0xf7888aec.
//
// Solidity: function balanceOf(address , address ) view returns(uint256)
func (_Settler *SettlerCallerSession) BalanceOf(arg0 common.Address, arg1 common.Address) (*big.Int, error) {
	return _Settler.Contract.BalanceOf(&_Settler.CallOpts, arg0, arg1)
}

// ComputeResultHash is a free data retrieval call binding the contract method 0xc6871485.
//
// Solidity: function computeResultHash((address,bytes32,bool,bool,uint128,uint128,uint64,bytes) arb, uint256 clearingPriceX128, (address,bytes32,bool,bool,uint128,uint128,uint64,uint64,bytes)[] intents) pure returns(bytes32)
func (_Settler *SettlerCaller) ComputeResultHash(opts *bind.CallOpts, arb ToBOrder, clearingPriceX128 *big.Int, intents []SwapIntent) ([32]byte, error) {
	var out []interface{}
	err := _Settler.contract.Call(opts, &out, "computeResultHash", arb, clearingPriceX128, intents)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ComputeResultHash is a free data retrieval call binding the contract method 0xc6871485.
//
// Solidity: function computeResultHash((address,bytes32,bool,bool,uint128,uint128,uint64,bytes) arb, uint256 clearingPriceX128, (address,bytes32,bool,bool,uint128,uint128,uint64,uint64,bytes)[] intents) pure returns(bytes32)
func (_Settler *SettlerSession) ComputeResultHash(arb ToBOrder, clearingPriceX128 *big.Int, intents []SwapIntent) ([32]byte, error) {
	return _Settler.Contract.ComputeResultHash(&_Settler.CallOpts, arb, clearingPriceX128, intents)
}

// ComputeResultHash is a free data retrieval call binding the contract method 0xc6871485.
//
// Solidity: function computeResultHash((address,bytes32,bool,bool,uint128,uint128,uint64,bytes) arb, uint256 clearingPriceX128, (address,bytes32,bool,bool,uint128,uint128,uint64,uint64,bytes)[] intents) pure returns(bytes32)
func (_Settler *SettlerCallerSession) ComputeResultHash(arb ToBOrder, clearingPriceX128 *big.Int, intents []SwapIntent) ([32]byte, error) {
	return _Settler.Contract.ComputeResultHash(&_Settler.CallOpts, arb, clearingPriceX128, intents)
}

// IsNonceUsed is a free data retrieval call binding the contract method 0x3a8a8beb.
//
// Solidity: function isNonceUsed(address user, uint64 nonce) view returns(bool)
func (_Settler *SettlerCaller) IsNonceUsed(opts *bind.CallOpts, user common.Address, nonce uint64) (bool, error) {
	var out []interface{}
	err := _Settler.contract.Call(opts, &out, "isNonceUsed", user, nonce)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsNonceUsed is a free data retrieval call binding the contract method 0x3a8a8beb.
//
// Solidity: function isNonceUsed(address user, uint64 nonce) view returns(bool)
func (_Settler *SettlerSession) IsNonceUsed(user common.Address, nonce uint64) (bool, error) {
	return _Settler.Contract.IsNonceUsed(&_Settler.CallOpts, user, nonce)
}

// IsNonceUsed is a free data retrieval call binding the contract method 0x3a8a8beb.
//
// Solidity: function isNonceUsed(address user, uint64 nonce) view returns(bool)
func (_Settler *SettlerCallerSession) IsNonceUsed(user common.Address, nonce uint64) (bool, error) {
	return _Settler.Contract.IsNonceUsed(&_Settler.CallOpts, user, nonce)
}

// OperatorFeeBps is a free data retrieval call binding the contract method 0xe17dd7c5.
//
// Solidity: function operatorFeeBps() view returns(uint256)
func (_Settler *SettlerCaller) OperatorFeeBps(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _Settler.contract.Call(opts, &out, "operatorFeeBps")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// OperatorFeeBps is a free data retrieval call binding the contract method 0xe17dd7c5.
//
// Solidity: function operatorFeeBps() view returns(uint256)
func (_Settler *SettlerSession) OperatorFeeBps() (*big.Int, error) {
	return _Settler.Contract.OperatorFeeBps(&_Settler.CallOpts)
}

// OperatorFeeBps is a free data retrieval call binding the contract method 0xe17dd7c5.
//
// Solidity: function operatorFeeBps() view returns(uint256)
func (_Settler *SettlerCallerSession) OperatorFeeBps() (*big.Int, error) {
	return _Settler.Contract.OperatorFeeBps(&_Settler.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_Settler *SettlerCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Settler.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_Settler *SettlerSession) Owner() (common.Address, error) {
	return _Settler.Contract.Owner(&_Settler.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_Settler *SettlerCallerSession) Owner() (common.Address, error) {
	return _Settler.Contract.Owner(&_Settler.CallOpts)
}

// PoolManager is a free data retrieval call binding the contract method 0xdc4c90d3.
//
// Solidity: function poolManager() view returns(address)
func (_Settler *SettlerCaller) PoolManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Settler.contract.Call(opts, &out, "poolManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PoolManager is a free data retrieval call binding the contract method 0xdc4c90d3.
//
// Solidity: function poolManager() view returns(address)
func (_Settler *SettlerSession) PoolManager() (common.Address, error) {
	return _Settler.Contract.PoolManager(&_Settler.CallOpts)
}

// PoolManager is a free data retrieval call binding the contract method 0xdc4c90d3.
//
// Solidity: function poolManager() view returns(address)
func (_Settler *SettlerCallerSession) PoolManager() (common.Address, error) {
	return _Settler.Contract.PoolManager(&_Settler.CallOpts)
}

// TaskManager is a free data retrieval call binding the contract method 0xa50a640e.
//
// Solidity: function taskManager() view returns(address)
func (_Settler *SettlerCaller) TaskManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Settler.contract.Call(opts, &out, "taskManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// TaskManager is a free data retrieval call binding the contract method 0xa50a640e.
//
// Solidity: function taskManager() view returns(address)
func (_Settler *SettlerSession) TaskManager() (common.Address, error) {
	return _Settler.Contract.TaskManager(&_Settler.CallOpts)
}

// TaskManager is a free data retrieval call binding the contract method 0xa50a640e.
//
// Solidity: function taskManager() view returns(address)
func (_Settler *SettlerCallerSession) TaskManager() (common.Address, error) {
	return _Settler.Contract.TaskManager(&_Settler.CallOpts)
}

// Deposit is a paid mutator transaction binding the contract method 0x47e7ef24.
//
// Solidity: function deposit(address asset, uint256 amount) returns()
func (_Settler *SettlerTransactor) Deposit(opts *bind.TransactOpts, asset common.Address, amount *big.Int) (*types.Transaction, error) {
	return _Settler.contract.Transact(opts, "deposit", asset, amount)
}

// Deposit is a paid mutator transaction binding the contract method 0x47e7ef24.
//
// Solidity: function deposit(address asset, uint256 amount) returns()
func (_Settler *SettlerSession) Deposit(asset common.Address, amount *big.Int) (*types.Transaction, error) {
	return _Settler.Contract.Deposit(&_Settler.TransactOpts, asset, amount)
}

// Deposit is a paid mutator transaction binding the contract method 0x47e7ef24.
//
// Solidity: function deposit(address asset, uint256 amount) returns()
func (_Settler *SettlerTransactorSession) Deposit(asset common.Address, amount *big.Int) (*types.Transaction, error) {
	return _Settler.Contract.Deposit(&_Settler.TransactOpts, asset, amount)
}

// InvalidateNonce is a paid mutator transaction binding the contract method 0x116a5550.
//
// Solidity: function invalidateNonce(uint64 nonce) returns()
func (_Settler *SettlerTransactor) InvalidateNonce(opts *bind.TransactOpts, nonce uint64) (*types.Transaction, error) {
	return _Settler.contract.Transact(opts, "invalidateNonce", nonce)
}

// InvalidateNonce is a paid mutator transaction binding the contract method 0x116a5550.
//
// Solidity: function invalidateNonce(uint64 nonce) returns()
func (_Settler *SettlerSession) InvalidateNonce(nonce uint64) (*types.Transaction, error) {
	return _Settler.Contract.InvalidateNonce(&_Settler.TransactOpts, nonce)
}

// InvalidateNonce is a paid mutator transaction binding the contract method 0x116a5550.
//
// Solidity: function invalidateNonce(uint64 nonce) returns()
func (_Settler *SettlerTransactorSession) InvalidateNonce(nonce uint64) (*types.Transaction, error) {
	return _Settler.Contract.InvalidateNonce(&_Settler.TransactOpts, nonce)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_Settler *SettlerTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Settler.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_Settler *SettlerSession) RenounceOwnership() (*types.Transaction, error) {
	return _Settler.Contract.RenounceOwnership(&_Settler.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_Settler *SettlerTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _Settler.Contract.RenounceOwnership(&_Settler.TransactOpts)
}

// SetOperatorFeeBps is a paid mutator transaction binding the contract method 0xaf935b04.
//
// Solidity: function setOperatorFeeBps(uint256 newOperatorFeeBps) returns()
func (_Settler *SettlerTransactor) SetOperatorFeeBps(opts *bind.TransactOpts, newOperatorFeeBps *big.Int) (*types.Transaction, error) {
	return _Settler.contract.Transact(opts, "setOperatorFeeBps", newOperatorFeeBps)
}

// SetOperatorFeeBps is a paid mutator transaction binding the contract method 0xaf935b04.
//
// Solidity: function setOperatorFeeBps(uint256 newOperatorFeeBps) returns()
func (_Settler *SettlerSession) SetOperatorFeeBps(newOperatorFeeBps *big.Int) (*types.Transaction, error) {
	return _Settler.Contract.SetOperatorFeeBps(&_Settler.TransactOpts, newOperatorFeeBps)
}

// SetOperatorFeeBps is a paid mutator transaction binding the contract method 0xaf935b04.
//
// Solidity: function setOperatorFeeBps(uint256 newOperatorFeeBps) returns()
func (_Settler *SettlerTransactorSession) SetOperatorFeeBps(newOperatorFeeBps *big.Int) (*types.Transaction, error) {
	return _Settler.Contract.SetOperatorFeeBps(&_Settler.TransactOpts, newOperatorFeeBps)
}

// Settle is a paid mutator transaction binding the contract method 0x2ecd134d.
//
// Solidity: function settle((address,address,uint24,int24,address) key, (address,bytes32,bool,bool,uint128,uint128,uint64,bytes) arb, (address,bytes32,bool,bool,uint128,uint128,uint64,uint64,bytes)[] intents, uint256 clearingPriceX128) returns()
func (_Settler *SettlerTransactor) Settle(opts *bind.TransactOpts, key PoolKey, arb ToBOrder, intents []SwapIntent, clearingPriceX128 *big.Int) (*types.Transaction, error) {
	return _Settler.contract.Transact(opts, "settle", key, arb, intents, clearingPriceX128)
}

// Settle is a paid mutator transaction binding the contract method 0x2ecd134d.
//
// Solidity: function settle((address,address,uint24,int24,address) key, (address,bytes32,bool,bool,uint128,uint128,uint64,bytes) arb, (address,bytes32,bool,bool,uint128,uint128,uint64,uint64,bytes)[] intents, uint256 clearingPriceX128) returns()
func (_Settler *SettlerSession) Settle(key PoolKey, arb ToBOrder, intents []SwapIntent, clearingPriceX128 *big.Int) (*types.Transaction, error) {
	return _Settler.Contract.Settle(&_Settler.TransactOpts, key, arb, intents, clearingPriceX128)
}

// Settle is a paid mutator transaction binding the contract method 0x2ecd134d.
//
// Solidity: function settle((address,address,uint24,int24,address) key, (address,bytes32,bool,bool,uint128,uint128,uint64,bytes) arb, (address,bytes32,bool,bool,uint128,uint128,uint64,uint64,bytes)[] intents, uint256 clearingPriceX128) returns()
func (_Settler *SettlerTransactorSession) Settle(key PoolKey, arb ToBOrder, intents []SwapIntent, clearingPriceX128 *big.Int) (*types.Transaction, error) {
	return _Settler.Contract.Settle(&_Settler.TransactOpts, key, arb, intents, clearingPriceX128)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_Settler *SettlerTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _Settler.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_Settler *SettlerSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _Settler.Contract.TransferOwnership(&_Settler.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_Settler *SettlerTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _Settler.Contract.TransferOwnership(&_Settler.TransactOpts, newOwner)
}

// UnlockCallback is a paid mutator transaction binding the contract method 0x91dd7346.
//
// Solidity: function unlockCallback(bytes data) returns(bytes)
func (_Settler *SettlerTransactor) UnlockCallback(opts *bind.TransactOpts, data []byte) (*types.Transaction, error) {
	return _Settler.contract.Transact(opts, "unlockCallback", data)
}

// UnlockCallback is a paid mutator transaction binding the contract method 0x91dd7346.
//
// Solidity: function unlockCallback(bytes data) returns(bytes)
func (_Settler *SettlerSession) UnlockCallback(data []byte) (*types.Transaction, error) {
	return _Settler.Contract.UnlockCallback(&_Settler.TransactOpts, data)
}

// UnlockCallback is a paid mutator transaction binding the contract method 0x91dd7346.
//
// Solidity: function unlockCallback(bytes data) returns(bytes)
func (_Settler *SettlerTransactorSession) UnlockCallback(data []byte) (*types.Transaction, error) {
	return _Settler.Contract.UnlockCallback(&_Settler.TransactOpts, data)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf3fef3a3.
//
// Solidity: function withdraw(address asset, uint256 amount) returns()
func (_Settler *SettlerTransactor) Withdraw(opts *bind.TransactOpts, asset common.Address, amount *big.Int) (*types.Transaction, error) {
	return _Settler.contract.Transact(opts, "withdraw", asset, amount)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf3fef3a3.
//
// Solidity: function withdraw(address asset, uint256 amount) returns()
func (_Settler *SettlerSession) Withdraw(asset common.Address, amount *big.Int) (*types.Transaction, error) {
	return _Settler.Contract.Withdraw(&_Settler.TransactOpts, asset, amount)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf3fef3a3.
//
// Solidity: function withdraw(address asset, uint256 amount) returns()
func (_Settler *SettlerTransactorSession) Withdraw(asset common.Address, amount *big.Int) (*types.Transaction, error) {
	return _Settler.Contract.Withdraw(&_Settler.TransactOpts, asset, amount)
}

// SettlerArbFilledIterator is returned from FilterArbFilled and is used to iterate over the raw logs and unpacked data for ArbFilled events raised by the Settler contract.
type SettlerArbFilledIterator struct {
	Event *SettlerArbFilled // Event containing the contract specifics and raw log

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
func (it *SettlerArbFilledIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SettlerArbFilled)
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
		it.Event = new(SettlerArbFilled)
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
func (it *SettlerArbFilledIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SettlerArbFilledIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SettlerArbFilled represents a ArbFilled event raised by the Settler contract.
type SettlerArbFilled struct {
	PoolId [32]byte
	Arber  common.Address
	Bid    *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterArbFilled is a free log retrieval operation binding the contract event 0x2cdf1d8f298e31fdab6d48bd3f624a6b426710a0f801646e779f0b7b202227c6.
//
// Solidity: event ArbFilled(bytes32 indexed poolId, address indexed arber, uint256 bid)
func (_Settler *SettlerFilterer) FilterArbFilled(opts *bind.FilterOpts, poolId [][32]byte, arber []common.Address) (*SettlerArbFilledIterator, error) {

	var poolIdRule []interface{}
	for _, poolIdItem := range poolId {
		poolIdRule = append(poolIdRule, poolIdItem)
	}
	var arberRule []interface{}
	for _, arberItem := range arber {
		arberRule = append(arberRule, arberItem)
	}

	logs, sub, err := _Settler.contract.FilterLogs(opts, "ArbFilled", poolIdRule, arberRule)
	if err != nil {
		return nil, err
	}
	return &SettlerArbFilledIterator{contract: _Settler.contract, event: "ArbFilled", logs: logs, sub: sub}, nil
}

// WatchArbFilled is a free log subscription operation binding the contract event 0x2cdf1d8f298e31fdab6d48bd3f624a6b426710a0f801646e779f0b7b202227c6.
//
// Solidity: event ArbFilled(bytes32 indexed poolId, address indexed arber, uint256 bid)
func (_Settler *SettlerFilterer) WatchArbFilled(opts *bind.WatchOpts, sink chan<- *SettlerArbFilled, poolId [][32]byte, arber []common.Address) (event.Subscription, error) {

	var poolIdRule []interface{}
	for _, poolIdItem := range poolId {
		poolIdRule = append(poolIdRule, poolIdItem)
	}
	var arberRule []interface{}
	for _, arberItem := range arber {
		arberRule = append(arberRule, arberItem)
	}

	logs, sub, err := _Settler.contract.WatchLogs(opts, "ArbFilled", poolIdRule, arberRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SettlerArbFilled)
				if err := _Settler.contract.UnpackLog(event, "ArbFilled", log); err != nil {
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

// ParseArbFilled is a log parse operation binding the contract event 0x2cdf1d8f298e31fdab6d48bd3f624a6b426710a0f801646e779f0b7b202227c6.
//
// Solidity: event ArbFilled(bytes32 indexed poolId, address indexed arber, uint256 bid)
func (_Settler *SettlerFilterer) ParseArbFilled(log types.Log) (*SettlerArbFilled, error) {
	event := new(SettlerArbFilled)
	if err := _Settler.contract.UnpackLog(event, "ArbFilled", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SettlerBlockSettledIterator is returned from FilterBlockSettled and is used to iterate over the raw logs and unpacked data for BlockSettled events raised by the Settler contract.
type SettlerBlockSettledIterator struct {
	Event *SettlerBlockSettled // Event containing the contract specifics and raw log

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
func (it *SettlerBlockSettledIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SettlerBlockSettled)
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
		it.Event = new(SettlerBlockSettled)
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
func (it *SettlerBlockSettledIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SettlerBlockSettledIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SettlerBlockSettled represents a BlockSettled event raised by the Settler contract.
type SettlerBlockSettled struct {
	PoolId      [32]byte
	BlockNumber *big.Int
	Operator    common.Address
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterBlockSettled is a free log retrieval operation binding the contract event 0xe3a54e1577137ab425dba27cbaefd144231efe25efbb9ac504503d339f1586ff.
//
// Solidity: event BlockSettled(bytes32 indexed poolId, uint256 indexed blockNumber, address indexed operator)
func (_Settler *SettlerFilterer) FilterBlockSettled(opts *bind.FilterOpts, poolId [][32]byte, blockNumber []*big.Int, operator []common.Address) (*SettlerBlockSettledIterator, error) {

	var poolIdRule []interface{}
	for _, poolIdItem := range poolId {
		poolIdRule = append(poolIdRule, poolIdItem)
	}
	var blockNumberRule []interface{}
	for _, blockNumberItem := range blockNumber {
		blockNumberRule = append(blockNumberRule, blockNumberItem)
	}
	var operatorRule []interface{}
	for _, operatorItem := range operator {
		operatorRule = append(operatorRule, operatorItem)
	}

	logs, sub, err := _Settler.contract.FilterLogs(opts, "BlockSettled", poolIdRule, blockNumberRule, operatorRule)
	if err != nil {
		return nil, err
	}
	return &SettlerBlockSettledIterator{contract: _Settler.contract, event: "BlockSettled", logs: logs, sub: sub}, nil
}

// WatchBlockSettled is a free log subscription operation binding the contract event 0xe3a54e1577137ab425dba27cbaefd144231efe25efbb9ac504503d339f1586ff.
//
// Solidity: event BlockSettled(bytes32 indexed poolId, uint256 indexed blockNumber, address indexed operator)
func (_Settler *SettlerFilterer) WatchBlockSettled(opts *bind.WatchOpts, sink chan<- *SettlerBlockSettled, poolId [][32]byte, blockNumber []*big.Int, operator []common.Address) (event.Subscription, error) {

	var poolIdRule []interface{}
	for _, poolIdItem := range poolId {
		poolIdRule = append(poolIdRule, poolIdItem)
	}
	var blockNumberRule []interface{}
	for _, blockNumberItem := range blockNumber {
		blockNumberRule = append(blockNumberRule, blockNumberItem)
	}
	var operatorRule []interface{}
	for _, operatorItem := range operator {
		operatorRule = append(operatorRule, operatorItem)
	}

	logs, sub, err := _Settler.contract.WatchLogs(opts, "BlockSettled", poolIdRule, blockNumberRule, operatorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SettlerBlockSettled)
				if err := _Settler.contract.UnpackLog(event, "BlockSettled", log); err != nil {
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

// ParseBlockSettled is a log parse operation binding the contract event 0xe3a54e1577137ab425dba27cbaefd144231efe25efbb9ac504503d339f1586ff.
//
// Solidity: event BlockSettled(bytes32 indexed poolId, uint256 indexed blockNumber, address indexed operator)
func (_Settler *SettlerFilterer) ParseBlockSettled(log types.Log) (*SettlerBlockSettled, error) {
	event := new(SettlerBlockSettled)
	if err := _Settler.contract.UnpackLog(event, "BlockSettled", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SettlerDepositedIterator is returned from FilterDeposited and is used to iterate over the raw logs and unpacked data for Deposited events raised by the Settler contract.
type SettlerDepositedIterator struct {
	Event *SettlerDeposited // Event containing the contract specifics and raw log

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
func (it *SettlerDepositedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SettlerDeposited)
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
		it.Event = new(SettlerDeposited)
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
func (it *SettlerDepositedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SettlerDepositedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SettlerDeposited represents a Deposited event raised by the Settler contract.
type SettlerDeposited struct {
	Asset  common.Address
	User   common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterDeposited is a free log retrieval operation binding the contract event 0x8752a472e571a816aea92eec8dae9baf628e840f4929fbcc2d155e6233ff68a7.
//
// Solidity: event Deposited(address indexed asset, address indexed user, uint256 amount)
func (_Settler *SettlerFilterer) FilterDeposited(opts *bind.FilterOpts, asset []common.Address, user []common.Address) (*SettlerDepositedIterator, error) {

	var assetRule []interface{}
	for _, assetItem := range asset {
		assetRule = append(assetRule, assetItem)
	}
	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _Settler.contract.FilterLogs(opts, "Deposited", assetRule, userRule)
	if err != nil {
		return nil, err
	}
	return &SettlerDepositedIterator{contract: _Settler.contract, event: "Deposited", logs: logs, sub: sub}, nil
}

// WatchDeposited is a free log subscription operation binding the contract event 0x8752a472e571a816aea92eec8dae9baf628e840f4929fbcc2d155e6233ff68a7.
//
// Solidity: event Deposited(address indexed asset, address indexed user, uint256 amount)
func (_Settler *SettlerFilterer) WatchDeposited(opts *bind.WatchOpts, sink chan<- *SettlerDeposited, asset []common.Address, user []common.Address) (event.Subscription, error) {

	var assetRule []interface{}
	for _, assetItem := range asset {
		assetRule = append(assetRule, assetItem)
	}
	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _Settler.contract.WatchLogs(opts, "Deposited", assetRule, userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SettlerDeposited)
				if err := _Settler.contract.UnpackLog(event, "Deposited", log); err != nil {
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

// ParseDeposited is a log parse operation binding the contract event 0x8752a472e571a816aea92eec8dae9baf628e840f4929fbcc2d155e6233ff68a7.
//
// Solidity: event Deposited(address indexed asset, address indexed user, uint256 amount)
func (_Settler *SettlerFilterer) ParseDeposited(log types.Log) (*SettlerDeposited, error) {
	event := new(SettlerDeposited)
	if err := _Settler.contract.UnpackLog(event, "Deposited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SettlerIntentFilledIterator is returned from FilterIntentFilled and is used to iterate over the raw logs and unpacked data for IntentFilled events raised by the Settler contract.
type SettlerIntentFilledIterator struct {
	Event *SettlerIntentFilled // Event containing the contract specifics and raw log

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
func (it *SettlerIntentFilledIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SettlerIntentFilled)
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
		it.Event = new(SettlerIntentFilled)
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
func (it *SettlerIntentFilledIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SettlerIntentFilledIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SettlerIntentFilled represents a IntentFilled event raised by the Settler contract.
type SettlerIntentFilled struct {
	PoolId     [32]byte
	User       common.Address
	ZeroForOne bool
	AmountIn   *big.Int
	AmountOut  *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterIntentFilled is a free log retrieval operation binding the contract event 0x9cc3aa1289d4afba3aeb6137518a1b5dd593552013f46afe57f82992bc51a0f4.
//
// Solidity: event IntentFilled(bytes32 indexed poolId, address indexed user, bool zeroForOne, uint256 amountIn, uint256 amountOut)
func (_Settler *SettlerFilterer) FilterIntentFilled(opts *bind.FilterOpts, poolId [][32]byte, user []common.Address) (*SettlerIntentFilledIterator, error) {

	var poolIdRule []interface{}
	for _, poolIdItem := range poolId {
		poolIdRule = append(poolIdRule, poolIdItem)
	}
	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _Settler.contract.FilterLogs(opts, "IntentFilled", poolIdRule, userRule)
	if err != nil {
		return nil, err
	}
	return &SettlerIntentFilledIterator{contract: _Settler.contract, event: "IntentFilled", logs: logs, sub: sub}, nil
}

// WatchIntentFilled is a free log subscription operation binding the contract event 0x9cc3aa1289d4afba3aeb6137518a1b5dd593552013f46afe57f82992bc51a0f4.
//
// Solidity: event IntentFilled(bytes32 indexed poolId, address indexed user, bool zeroForOne, uint256 amountIn, uint256 amountOut)
func (_Settler *SettlerFilterer) WatchIntentFilled(opts *bind.WatchOpts, sink chan<- *SettlerIntentFilled, poolId [][32]byte, user []common.Address) (event.Subscription, error) {

	var poolIdRule []interface{}
	for _, poolIdItem := range poolId {
		poolIdRule = append(poolIdRule, poolIdItem)
	}
	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _Settler.contract.WatchLogs(opts, "IntentFilled", poolIdRule, userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SettlerIntentFilled)
				if err := _Settler.contract.UnpackLog(event, "IntentFilled", log); err != nil {
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

// ParseIntentFilled is a log parse operation binding the contract event 0x9cc3aa1289d4afba3aeb6137518a1b5dd593552013f46afe57f82992bc51a0f4.
//
// Solidity: event IntentFilled(bytes32 indexed poolId, address indexed user, bool zeroForOne, uint256 amountIn, uint256 amountOut)
func (_Settler *SettlerFilterer) ParseIntentFilled(log types.Log) (*SettlerIntentFilled, error) {
	event := new(SettlerIntentFilled)
	if err := _Settler.contract.UnpackLog(event, "IntentFilled", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SettlerNonceInvalidatedIterator is returned from FilterNonceInvalidated and is used to iterate over the raw logs and unpacked data for NonceInvalidated events raised by the Settler contract.
type SettlerNonceInvalidatedIterator struct {
	Event *SettlerNonceInvalidated // Event containing the contract specifics and raw log

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
func (it *SettlerNonceInvalidatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SettlerNonceInvalidated)
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
		it.Event = new(SettlerNonceInvalidated)
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
func (it *SettlerNonceInvalidatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SettlerNonceInvalidatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SettlerNonceInvalidated represents a NonceInvalidated event raised by the Settler contract.
type SettlerNonceInvalidated struct {
	User  common.Address
	Nonce uint64
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterNonceInvalidated is a free log retrieval operation binding the contract event 0x96f5aa72c67d8b8b2cab9d2e5fe3ed0b101e8730b79b86ea82042ca99a8817d1.
//
// Solidity: event NonceInvalidated(address indexed user, uint64 nonce)
func (_Settler *SettlerFilterer) FilterNonceInvalidated(opts *bind.FilterOpts, user []common.Address) (*SettlerNonceInvalidatedIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _Settler.contract.FilterLogs(opts, "NonceInvalidated", userRule)
	if err != nil {
		return nil, err
	}
	return &SettlerNonceInvalidatedIterator{contract: _Settler.contract, event: "NonceInvalidated", logs: logs, sub: sub}, nil
}

// WatchNonceInvalidated is a free log subscription operation binding the contract event 0x96f5aa72c67d8b8b2cab9d2e5fe3ed0b101e8730b79b86ea82042ca99a8817d1.
//
// Solidity: event NonceInvalidated(address indexed user, uint64 nonce)
func (_Settler *SettlerFilterer) WatchNonceInvalidated(opts *bind.WatchOpts, sink chan<- *SettlerNonceInvalidated, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _Settler.contract.WatchLogs(opts, "NonceInvalidated", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SettlerNonceInvalidated)
				if err := _Settler.contract.UnpackLog(event, "NonceInvalidated", log); err != nil {
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

// ParseNonceInvalidated is a log parse operation binding the contract event 0x96f5aa72c67d8b8b2cab9d2e5fe3ed0b101e8730b79b86ea82042ca99a8817d1.
//
// Solidity: event NonceInvalidated(address indexed user, uint64 nonce)
func (_Settler *SettlerFilterer) ParseNonceInvalidated(log types.Log) (*SettlerNonceInvalidated, error) {
	event := new(SettlerNonceInvalidated)
	if err := _Settler.contract.UnpackLog(event, "NonceInvalidated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SettlerOperatorFeeBpsSetIterator is returned from FilterOperatorFeeBpsSet and is used to iterate over the raw logs and unpacked data for OperatorFeeBpsSet events raised by the Settler contract.
type SettlerOperatorFeeBpsSetIterator struct {
	Event *SettlerOperatorFeeBpsSet // Event containing the contract specifics and raw log

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
func (it *SettlerOperatorFeeBpsSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SettlerOperatorFeeBpsSet)
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
		it.Event = new(SettlerOperatorFeeBpsSet)
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
func (it *SettlerOperatorFeeBpsSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SettlerOperatorFeeBpsSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SettlerOperatorFeeBpsSet represents a OperatorFeeBpsSet event raised by the Settler contract.
type SettlerOperatorFeeBpsSet struct {
	NewOperatorFeeBps *big.Int
	Raw               types.Log // Blockchain specific contextual infos
}

// FilterOperatorFeeBpsSet is a free log retrieval operation binding the contract event 0xecf72c9ac9f8f5ea2bb6a3c6fbbeff4107883d5e51388cc5e24b0dba5f5a2fe6.
//
// Solidity: event OperatorFeeBpsSet(uint256 newOperatorFeeBps)
func (_Settler *SettlerFilterer) FilterOperatorFeeBpsSet(opts *bind.FilterOpts) (*SettlerOperatorFeeBpsSetIterator, error) {

	logs, sub, err := _Settler.contract.FilterLogs(opts, "OperatorFeeBpsSet")
	if err != nil {
		return nil, err
	}
	return &SettlerOperatorFeeBpsSetIterator{contract: _Settler.contract, event: "OperatorFeeBpsSet", logs: logs, sub: sub}, nil
}

// WatchOperatorFeeBpsSet is a free log subscription operation binding the contract event 0xecf72c9ac9f8f5ea2bb6a3c6fbbeff4107883d5e51388cc5e24b0dba5f5a2fe6.
//
// Solidity: event OperatorFeeBpsSet(uint256 newOperatorFeeBps)
func (_Settler *SettlerFilterer) WatchOperatorFeeBpsSet(opts *bind.WatchOpts, sink chan<- *SettlerOperatorFeeBpsSet) (event.Subscription, error) {

	logs, sub, err := _Settler.contract.WatchLogs(opts, "OperatorFeeBpsSet")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SettlerOperatorFeeBpsSet)
				if err := _Settler.contract.UnpackLog(event, "OperatorFeeBpsSet", log); err != nil {
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

// ParseOperatorFeeBpsSet is a log parse operation binding the contract event 0xecf72c9ac9f8f5ea2bb6a3c6fbbeff4107883d5e51388cc5e24b0dba5f5a2fe6.
//
// Solidity: event OperatorFeeBpsSet(uint256 newOperatorFeeBps)
func (_Settler *SettlerFilterer) ParseOperatorFeeBpsSet(log types.Log) (*SettlerOperatorFeeBpsSet, error) {
	event := new(SettlerOperatorFeeBpsSet)
	if err := _Settler.contract.UnpackLog(event, "OperatorFeeBpsSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SettlerOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the Settler contract.
type SettlerOwnershipTransferredIterator struct {
	Event *SettlerOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *SettlerOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SettlerOwnershipTransferred)
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
		it.Event = new(SettlerOwnershipTransferred)
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
func (it *SettlerOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SettlerOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SettlerOwnershipTransferred represents a OwnershipTransferred event raised by the Settler contract.
type SettlerOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_Settler *SettlerFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*SettlerOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _Settler.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &SettlerOwnershipTransferredIterator{contract: _Settler.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_Settler *SettlerFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *SettlerOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _Settler.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SettlerOwnershipTransferred)
				if err := _Settler.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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

// ParseOwnershipTransferred is a log parse operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_Settler *SettlerFilterer) ParseOwnershipTransferred(log types.Log) (*SettlerOwnershipTransferred, error) {
	event := new(SettlerOwnershipTransferred)
	if err := _Settler.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SettlerWithdrawnIterator is returned from FilterWithdrawn and is used to iterate over the raw logs and unpacked data for Withdrawn events raised by the Settler contract.
type SettlerWithdrawnIterator struct {
	Event *SettlerWithdrawn // Event containing the contract specifics and raw log

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
func (it *SettlerWithdrawnIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SettlerWithdrawn)
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
		it.Event = new(SettlerWithdrawn)
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
func (it *SettlerWithdrawnIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SettlerWithdrawnIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SettlerWithdrawn represents a Withdrawn event raised by the Settler contract.
type SettlerWithdrawn struct {
	Asset  common.Address
	User   common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterWithdrawn is a free log retrieval operation binding the contract event 0xd1c19fbcd4551a5edfb66d43d2e337c04837afda3482b42bdf569a8fccdae5fb.
//
// Solidity: event Withdrawn(address indexed asset, address indexed user, uint256 amount)
func (_Settler *SettlerFilterer) FilterWithdrawn(opts *bind.FilterOpts, asset []common.Address, user []common.Address) (*SettlerWithdrawnIterator, error) {

	var assetRule []interface{}
	for _, assetItem := range asset {
		assetRule = append(assetRule, assetItem)
	}
	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _Settler.contract.FilterLogs(opts, "Withdrawn", assetRule, userRule)
	if err != nil {
		return nil, err
	}
	return &SettlerWithdrawnIterator{contract: _Settler.contract, event: "Withdrawn", logs: logs, sub: sub}, nil
}

// WatchWithdrawn is a free log subscription operation binding the contract event 0xd1c19fbcd4551a5edfb66d43d2e337c04837afda3482b42bdf569a8fccdae5fb.
//
// Solidity: event Withdrawn(address indexed asset, address indexed user, uint256 amount)
func (_Settler *SettlerFilterer) WatchWithdrawn(opts *bind.WatchOpts, sink chan<- *SettlerWithdrawn, asset []common.Address, user []common.Address) (event.Subscription, error) {

	var assetRule []interface{}
	for _, assetItem := range asset {
		assetRule = append(assetRule, assetItem)
	}
	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _Settler.contract.WatchLogs(opts, "Withdrawn", assetRule, userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SettlerWithdrawn)
				if err := _Settler.contract.UnpackLog(event, "Withdrawn", log); err != nil {
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

// ParseWithdrawn is a log parse operation binding the contract event 0xd1c19fbcd4551a5edfb66d43d2e337c04837afda3482b42bdf569a8fccdae5fb.
//
// Solidity: event Withdrawn(address indexed asset, address indexed user, uint256 amount)
func (_Settler *SettlerFilterer) ParseWithdrawn(log types.Log) (*SettlerWithdrawn, error) {
	event := new(SettlerWithdrawn)
	if err := _Settler.contract.UnpackLog(event, "Withdrawn", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
