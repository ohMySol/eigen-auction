import type { ToBOrderT, SwapIntentT } from "@eigen-auction/shared";

// The sealed set for a block, in the exact wire shape the Go operator decodes (avs/internal/feed).
// bigints are decimal strings; block numbers are JSON numbers; addresses/poolId/signatures are 0x-hex.
export interface OrderWire {
    searcher: string;
    poolId: string;
    zeroForOne: boolean;
    useInternal: boolean;
    quantityIn: string;
    quantityOut: string;
    validForBlock: number;
    signature: string;
}

export interface IntentWire {
    user: string;
    poolId: string;
    zeroForOne: boolean;
    useInternal: boolean;
    amountIn: string;
    minAmountOut: string;
    nonce: number;
    deadline: number;
    signature: string;
}

export interface SealedSetWire {
    targetBlock: number;
    referenceBlockNumber: number;
    clearingPriceX128: string;
    orders: OrderWire[];
    intents: IntentWire[];
}

// FROZEN clearing-price derivation (§2.2b) — the single consensus input with no on-chain formula, so
// it is defined here and stamped identically for every operator. Basis: currency1-raw per currency0-raw
// in Q128. Input `pricePerCurrency0` is currency1 whole units per 1 currency0 whole unit — the same
// convention as config.fixedPrice (e.g. 0.0005 WETH per USDC). Converting whole→raw units:
//   clearingPriceX128 = pricePerCurrency0 * 10^(decimals1 - decimals0) * 2^128
// so that out_currency1_raw = in_currency0_raw * clearingPriceX128 / 2^128 (the Settler's convention).
// The price may be fractional, so it is carried as a 1e18-scaled integer to stay in BigInt. Float
// imprecision here is harmless: the relay stamps ONE integer that every operator reads, so there is no
// cross-operator divergence to worry about (the whole reason the relay owns this value).
export function clearingPriceX128(pricePerCurrency0: number, decimals0: number, decimals1: number): bigint {
    const PRICE_SCALE = 10n ** 18n;
    const scaledPrice = BigInt(Math.round(pricePerCurrency0 * 1e18));
    return (scaledPrice * (10n ** BigInt(decimals1)) << 128n) / (PRICE_SCALE * (10n ** BigInt(decimals0)));
}

// referenceBlockNumber is a deterministic function of the target block (not of the caller's current
// head), so every operator that seals block N agrees on the stake snapshot + prevrandao block. It must
// be a confirmed past block < targetBlock; with the operator's settle offset of 2, N-2 is exactly the
// head at the moment operators process N.
export const REF_OFFSET = 2;

function orderWire(o: ToBOrderT): OrderWire {
    return {
        searcher: o.searcher,
        poolId: o.poolId,
        zeroForOne: o.zeroForOne,
        useInternal: o.useInternal,
        quantityIn: o.quantityIn.toString(),
        quantityOut: o.quantityOut.toString(),
        validForBlock: Number(o.validForBlock),
        signature: o.signature,
    };
}

function intentWire(i: SwapIntentT): IntentWire {
    return {
        user: i.user,
        poolId: i.poolId,
        zeroForOne: i.zeroForOne,
        useInternal: i.useInternal,
        amountIn: i.amountIn.toString(),
        minAmountOut: i.minAmountOut.toString(),
        nonce: Number(i.nonce),
        deadline: Number(i.deadline),
        signature: i.signature,
    };
}

export interface SealParams {
    targetBlock: number;
    orders: ToBOrderT[];
    intents: SwapIntentT[];
    humanPrice: number;
    decimals0: number;
    decimals1: number;
}

// Build the canonical sealed set for a block: the orders scoped to it, the pending intents, and the
// stamped clearing price + reference block. Returned identically to every operator that GETs the block.
export function buildSealedSet(p: SealParams): SealedSetWire {
    return {
        targetBlock: p.targetBlock,
        referenceBlockNumber: p.targetBlock - REF_OFFSET,
        clearingPriceX128: clearingPriceX128(p.humanPrice, p.decimals0, p.decimals1).toString(),
        orders: p.orders.map(orderWire),
        intents: p.intents.map(intentWire),
    };
}
