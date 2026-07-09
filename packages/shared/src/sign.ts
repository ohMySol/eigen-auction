import { hashTypedData, recoverTypedDataAddress, type Account, type Address, type Hex } from "viem";
import { SwapIntentT, ToBOrderT } from "./types";

// The schema for the intent signature. It mirrors the fields on the SwapIntent Solidity struct.
export const INTENT_TYPES = {
  SwapIntent: [
    { name: "user", type: "address" },
    { name: "poolId", type: "bytes32" },
    { name: "zeroForOne", type: "bool" },
    { name: "useInternal", type: "bool" },
    { name: "amountIn", type: "uint128" },
    { name: "minAmountOut", type: "uint128" },
    { name: "nonce", type: "uint64" },
    { name: "deadline", type: "uint64" },
 ],
} as const;

// The schema for the arb-order signature — mirrors the Solidity ToBOrder struct field-for-field
// (src/contracts/src/types/ToBOrder.sol). Signed under the same Settler domain as intents; the
// contract's _proveFraud recovers a challenged order against exactly this (domain, types, message).
export const ORDER_TYPES = {
  ToBOrder: [
    { name: "searcher", type: "address" },
    { name: "poolId", type: "bytes32" },
    { name: "zeroForOne", type: "bool" },
    { name: "useInternal", type: "bool" },
    { name: "quantityIn", type: "uint128" },
    { name: "quantityOut", type: "uint128" },
    { name: "validForBlock", type: "uint64" },
  ],
} as const;

// The EIP-712 domain separator, matching the one the Settler builds in its constructor. Binds a
// signature to a specific contract and chain, preventing replay — a signature for the Settler on one
// chain can't be replayed on another or against a different contract. Shared by intents and orders.
export function settlerDomain(settler: Address, chainId: number) {
  return {
    name: "EigenAuction Settler",
    version: "1",
    chainId,
    verifyingContract: settler
  } as const;
}

// Back-compat alias: the intent path historically imported this name.
export const intentDomain = settlerDomain;

// Function takes a viem Account, the Settler address, chain ID and the unsigned intent.
// `signTypedData` encodes the domain + types + message into a deterministic hash (EIP-712) -->
// signs that hash with the accounts private key --> returns the signature hex.
export async function signIntent(
  account: Account,
  settler: Address,
  chainId: number,
  intent: Omit<SwapIntentT, "signature">,
): Promise<Hex> {
  return account.signTypedData!({
    domain: settlerDomain(settler, chainId),
    types: INTENT_TYPES,
    primaryType: "SwapIntent",
    message: intent
  });
}

// Sign a searcher arb order (ToBOrder) under the Settler EIP-712 domain — the scheme the deployed
// EigenAuctionTaskManager verifies in _proveFraud, replacing the legacy EIP-191 bid. A signature that
// recovers to `order.searcher` here is byte-identical to one the contract accepts.
export async function signToBOrder(
  account: Account,
  settler: Address,
  chainId: number,
  order: Omit<ToBOrderT, "signature">,
): Promise<Hex> {
  return account.signTypedData!({
    domain: settlerDomain(settler, chainId),
    types: ORDER_TYPES,
    primaryType: "ToBOrder",
    message: order
  });
}

// The EIP-712 digest a searcher signs for an arb order: keccak256(0x1901 ++ domainSeparator ++
// toBStructHash). The Go operator reproduces this (avs/internal/consensus/orders.go OrderDigest) and
// recovers it against the order signature to reject forgeries; held byte-identical by a shared vector.
export function orderDigest(order: Omit<ToBOrderT, "signature">, settler: Address, chainId: number): Hex {
  return hashTypedData({
    domain: settlerDomain(settler, chainId),
    types: ORDER_TYPES,
    primaryType: "ToBOrder",
    message: order,
  });
}

// Recover the address that produced an arb order's signature. Operators call this to reject any
// order that isn't a genuine searcher commitment before counting it in the auction.
export async function recoverToBOrderSigner(
  settler: Address,
  chainId: number,
  order: ToBOrderT,
): Promise<Address> {
  const { signature, ...message } = order;
  return recoverTypedDataAddress({
    domain: settlerDomain(settler, chainId),
    types: ORDER_TYPES,
    primaryType: "ToBOrder",
    message,
    signature,
  });
}
