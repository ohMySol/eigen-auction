export const settlerAbi = [
 { type: "function", name: "settle", stateMutability: "nonpayable", inputs: [
   { name: "key", type: "tuple", components: [
    { name: "currency0", type: "address" }, { name: "currency1", type: "address" },
    { name: "fee", type: "uint24" }, { name: "tickSpacing", type: "int24" },
    { name: "hooks", type: "address" }] },
   { name: "rewardAmount", type: "uint256" },
   { name: "arb", type: "tuple", components: [
    { name: "zeroForOne", type: "bool" }, { name: "amountSpecified", type: "int256" },
    { name: "sqrtPriceLimitX96", type: "uint160" }] },
   { name: "intents", type: "tuple[]", components: [
    { name: "user", type: "address" }, { name: "poolId", type: "bytes32" },
    { name: "zeroForOne", type: "bool" }, { name: "amountIn", type: "uint128" },
    { name: "minAmountOut", type: "uint128" }, { name: "nonce", type: "uint64" },
    { name: "deadline", type: "uint64" }, { name: "signature", type: "bytes" }] },
  ], outputs: [] },
 { type: "function", name: "isNonceUsed", stateMutability: "view",
  inputs: [{ name: "user", type: "address" }, { name: "nonce", type: "uint64" }],
  outputs: [{ type: "bool" }] },
] as const;

// The deployed EigenAuctionTaskManager read surface used off-chain. `commitWinner`/`challenge` carry
// the large NonSignerStakesAndSignature/BN254 tuples and are called only from the Go aggregator (bound
// via abigen from the compiled artifact), so they are deliberately NOT transcribed here — only the
// commitment read + event the TS side consumes.
export const taskManagerAbi = [
 { type: "function", name: "getCommitment", stateMutability: "view", inputs: [
   { name: "poolId", type: "bytes32" }, { name: "targetBlock", type: "uint256" }],
  outputs: [{ name: "", type: "tuple", components: [
   { name: "resultHash", type: "bytes32" }, { name: "hashOfNonSigners", type: "bytes32" },
   { name: "executor", type: "address" }, { name: "exists", type: "bool" },
   { name: "challenged", type: "bool" }] }] },
 { type: "event", name: "WinnerCommitted", inputs: [
   { name: "poolId", type: "bytes32", indexed: true },
   { name: "targetBlock", type: "uint256", indexed: true },
   { name: "executor", type: "address", indexed: true },
   { name: "resultHash", type: "bytes32", indexed: false }] },
] as const;

export const stateViewAbi = [
 { type: "function", name: "getSlot0", stateMutability: "view",
  inputs: [{ name: "poolId", type: "bytes32" }], outputs: [
   { name: "sqrtPriceX96", type: "uint160" }, { name: "tick", type: "int24" },
   { name: "protocolFee", type: "uint24" }, { name: "lpFee", type: "uint24" }] },
 { type: "function", name: "getLiquidity", stateMutability: "view",
  inputs: [{ name: "poolId", type: "bytes32" }], outputs: [{ type: "uint128" }] },
] as const;

// EigenAuctionHook surface used off-chain: in-hook LP actions and the rewards view.
const poolKeyComponents = [
 { name: "currency0", type: "address" }, { name: "currency1", type: "address" },
 { name: "fee", type: "uint24" }, { name: "tickSpacing", type: "int24" }, { name: "hooks", type: "address" },
] as const;

export const eigenAuctionHookAbi = [
 { type: "function", name: "earned", stateMutability: "view", inputs: [
   { name: "key", type: "tuple", components: poolKeyComponents },
   { name: "owner", type: "address" }, { name: "tickLower", type: "int24" },
   { name: "tickUpper", type: "int24" }, { name: "salt", type: "bytes32" }],
  outputs: [{ name: "amount", type: "uint256" }] },
] as const;

// The per-round economic events, hand-written to match EventsLib.sol. The results reporter parses these
// from the settled block to surface what actually happened: the arb surplus captured for LPs (ArbFilled),
// the reward distributed to in-range liquidity (ArbitrageSettled), each user swap (IntentFilled), and
// which operator executed (BlockSettled). PoolId is a bytes32 value type on-chain.
export const auctionEventsAbi = [
 { type: "event", name: "ArbFilled", inputs: [
   { name: "poolId", type: "bytes32", indexed: true },
   { name: "arber", type: "address", indexed: true },
   { name: "bid", type: "uint256", indexed: false }] },
 { type: "event", name: "ArbitrageSettled", inputs: [
   { name: "poolId", type: "bytes32", indexed: true },
   { name: "winner", type: "address", indexed: true },
   { name: "rewardAmount", type: "uint256", indexed: false }] },
 { type: "event", name: "IntentFilled", inputs: [
   { name: "poolId", type: "bytes32", indexed: true },
   { name: "user", type: "address", indexed: true },
   { name: "zeroForOne", type: "bool", indexed: false },
   { name: "amountIn", type: "uint256", indexed: false },
   { name: "amountOut", type: "uint256", indexed: false }] },
 { type: "event", name: "BlockSettled", inputs: [
   { name: "poolId", type: "bytes32", indexed: true },
   { name: "blockNumber", type: "uint256", indexed: true },
   { name: "operator", type: "address", indexed: true }] },
] as const;
