// Canonical winner election (frozen rule A). Every operator runs this over the identical relay-sealed
// order set and clearing price, so all produce the same winning arb — hence the same resultHash and an
// aggregatable signature. The Go operator (avs/internal/consensus/auction.go) mirrors this exactly and
// is held to it by the shared golden vectors in test/auction.test.ts.
//
// Rule A: the winner is the eligible order that maximises the LP surplus it leaves at the sealed
// clearing price. This always lands on the Pareto frontier of (pays more token0, wants less token1),
// so no other order can strictly dominate it — the exact condition the contract's _proveFraud checks
// (EigenAuctionTaskManager._proveFraud), making a correct election un-challengeable.
import type { ToBOrderT } from "./types";
import { toBStructHash } from "./resultHash";

const Q128 = 1n << 128n;

// LP surplus (token1 units, scaled by Q128) the arb leaves at the clearing price:
//   score = quantityIn * clearingPriceX128 - quantityOut * Q128
// i.e. the token0 paid in, valued in token1 at the clearing price, minus the token1 taken out.
export function scoreOrder(o: ToBOrderT, clearingPriceX128: bigint): bigint {
    return o.quantityIn * clearingPriceX128 - o.quantityOut * Q128;
}

// Elect the winning arb for a block. Only orders with a strictly positive surplus are eligible — a
// non-positive arb costs LPs and is never executed. Ties (equal score) break on the lower EIP-712
// struct hash so every operator picks the identical winner. Returns null when nothing is eligible;
// the block then commits with no arb (arbOrderHash = bytes32(0)).
export function electWinner(orders: ToBOrderT[], clearingPriceX128: bigint): ToBOrderT | null {
    let best: ToBOrderT | null = null;
    let bestScore = 0n;
    let bestHash = "";
    for (const o of orders) {
        const s = scoreOrder(o, clearingPriceX128);
        if (s <= 0n) continue;
        const h = toBStructHash(o);
        if (best === null || s > bestScore || (s === bestScore && h < bestHash)) {
            best = o;
            bestScore = s;
            bestHash = h;
        }
    }
    return best;
}
