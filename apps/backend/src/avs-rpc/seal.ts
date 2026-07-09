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

// Why a discount is needed: `settle` fills every batch order at ONE uniform clearing price, but sources
// the net token flow from the AMM — which charges the 0.3% pool fee and moves price as it trades. If the
// clearing price were exactly mid, the users' input would only equal the mid-value of their output, so it
// would NOT cover what the pool charged to produce that output, and settle would revert insolvent
// (Settler_BatchInsolvent). Pricing slightly BELOW mid makes each fill collect a little more input than
// the AMM's cost; that surplus covers the fee + slippage and is left to LPs, keeping the batch solvent.
// This is the demo-simplified form: a full spec would apply the buffer only in the net-imbalance
// direction and could net opposing intents so only the residual pays the fee.
const SOLVENCY_DISCOUNT_BPS = 200n; // 2% below mid — covers the 0.3% pool fee + batch slippage + arb price impact

// FROZEN clearing-price derivation — the single consensus input with no on-chain formula, so
// it is defined here and stamped identically for every operator. Basis: currency1-raw per currency0-raw
// in Q128. Input `pricePerCurrency0` is currency1 whole units per 1 currency0 whole unit — the same
// convention as config.fixedPrice (e.g. 0.0005 WETH per USDC). Converting whole→raw units:
//   mid = pricePerCurrency0 * 10^(decimals1 - decimals0) * 2^128
// then apply the solvency discount so out_currency1_raw = in_currency0_raw * clearingPriceX128 / 2^128 stays solvent.
// The price may be fractional, so it is carried as a 1e18-scaled integer to stay in BigInt. Float
// imprecision here is harmless: the relay stamps ONE integer that every operator reads, so there is no
// cross-operator divergence to worry about (the whole reason the relay owns this value).
export function clearingPriceX128(pricePerCurrency0: number, decimals0: number, decimals1: number): bigint {
    const PRICE_SCALE = 10n ** 18n;
    const scaledPrice = BigInt(Math.round(pricePerCurrency0 * 1e18));
    const mid = (scaledPrice * (10n ** BigInt(decimals1)) << 128n) / (PRICE_SCALE * (10n ** BigInt(decimals0)));
    return (mid * (10_000n - SOLVENCY_DISCOUNT_BPS)) / 10_000n;
}

// referenceBlockNumber is a deterministic function of the target block (not of the caller's current
// head), so every operator that seals block N agrees on the stake snapshot + prevrandao block. It must
// be a confirmed past block < targetBlock; the operator targets head+1, so N-1 is the current head at
// seal time — a confirmed block, and strictly less than the target block the commit lands in.
export const REF_OFFSET = 1;

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
