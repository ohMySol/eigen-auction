// Canonical off-chain reproduction of the Settler's result-hash commitment. Every operator computes
// `resultHash` from the block's batch and BLS-signs it (inside `msgHash`); the Settler re-derives the
// same hash on-chain (Settler.computeResultHash) and reverts a settle that does not match. A single
// byte of divergence here breaks the whole quorum, so this MUST stay identical to the Solidity:
//   - src/contracts/src/types/ToBOrder.sol      (toBStructHash)
//   - src/contracts/src/types/SwapIntent.sol    (intentStructHash)
//   - src/contracts/src/Settler.sol             (computeResultHash)
// Cross-checked against the contract by test/resultHash.test.ts + a Solidity vector test on the same
// inputs. `useInternal` is part of both struct hashes — it is deliberately included here even though
// the pipeline's SwapIntentT does not carry it yet (that reconciliation is tracked separately).
import { keccak256, encodeAbiParameters, toBytes, type Hex } from "viem";
import type { ToBOrderT } from "./types";

// keccak256 of the exact EIP-712 type strings the contracts declare. Hashing the UTF-8 bytes mirrors
// Solidity's `keccak256("...")`.
export const TOB_ORDER_TYPEHASH: Hex = keccak256(
    toBytes(
        "ToBOrder(address searcher,bytes32 poolId,bool zeroForOne,bool useInternal," +
        "uint128 quantityIn,uint128 quantityOut,uint64 validForBlock)",
    ),
);

export const INTENT_TYPEHASH: Hex = keccak256(
    toBytes(
        "SwapIntent(address user,bytes32 poolId,bool zeroForOne,bool useInternal," +
        "uint128 amountIn,uint128 minAmountOut,uint64 nonce,uint64 deadline)",
    ),
);

// The intent fields that enter the struct hash (the signature is excluded). Defined locally and
// contract-exact so this reference does not depend on the pipeline's (currently useInternal-less)
// SwapIntentT.
export interface IntentTermsT {
    user: Hex;
    poolId: Hex;
    zeroForOne: boolean;
    useInternal: boolean;
    amountIn: bigint;
    minAmountOut: bigint;
    nonce: bigint;
    deadline: bigint;
}

// EIP-712 struct hash of an arb order's terms — keccak256(abi.encode(TYPEHASH, ...fields)).
export function toBStructHash(o: ToBOrderT): Hex {
    return keccak256(
        encodeAbiParameters(
            [
                { type: "bytes32" }, { type: "address" }, { type: "bytes32" },
                { type: "bool" }, { type: "bool" },
                { type: "uint128" }, { type: "uint128" }, { type: "uint64" },
            ],
            [
                TOB_ORDER_TYPEHASH, o.searcher, o.poolId,
                o.zeroForOne, o.useInternal,
                o.quantityIn, o.quantityOut, o.validForBlock,
            ],
        ),
    );
}

// EIP-712 struct hash of a swap intent's terms.
export function intentStructHash(i: IntentTermsT): Hex {
    return keccak256(
        encodeAbiParameters(
            [
                { type: "bytes32" }, { type: "address" }, { type: "bytes32" },
                { type: "bool" }, { type: "bool" },
                { type: "uint128" }, { type: "uint128" }, { type: "uint64" }, { type: "uint64" },
            ],
            [
                INTENT_TYPEHASH, i.user, i.poolId,
                i.zeroForOne, i.useInternal,
                i.amountIn, i.minAmountOut, i.nonce, i.deadline,
            ],
        ),
    );
}

// The per-block commitment the quorum attests, mirroring Settler.computeResultHash exactly:
//   arbOrderHash = hasArb ? toBStructHash(arb) : bytes32(0)
//   intentsRoot  = keccak256(abi.encode(bytes32[] intentHashes))
//   resultHash   = keccak256(abi.encode(arbOrderHash, clearingPriceX128, intentsRoot))
// An all-zero arb (quantityIn == quantityOut == 0) means "no arb this block" and hashes to bytes32(0).
export function computeResultHash(arb: ToBOrderT, clearingPriceX128: bigint, intents: IntentTermsT[]): Hex {
    const hasArb = arb.quantityIn !== 0n || arb.quantityOut !== 0n;
    const arbOrderHash: Hex = hasArb
        ? toBStructHash(arb)
        : "0x0000000000000000000000000000000000000000000000000000000000000000";

    const intentHashes = intents.map(intentStructHash);
    const intentsRoot = keccak256(encodeAbiParameters([{ type: "bytes32[]" }], [intentHashes]));

    return keccak256(
        encodeAbiParameters(
            [{ type: "bytes32" }, { type: "uint256" }, { type: "bytes32" }],
            [arbOrderHash, clearingPriceX128, intentsRoot],
        ),
    );
}
