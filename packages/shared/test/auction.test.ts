import { describe, it, expect } from "vitest";
import { electWinner, scoreOrder } from "../src/auction";
import type { ToBOrderT } from "../src/types";

// Golden vectors for the frozen election rule A, shared with the Go port
// (avs/internal/consensus/auction_test.go). Winner = eligible order with the greatest LP surplus at
// the clearing price; ties break on the lower toBStructHash; non-positive-surplus orders are ineligible.
const POOL_ID = "0x1111111111111111111111111111111111111111111111111111111111111111" as const;
const PRICE = 2000n << 128n; // clearing price: 2000 token1 per token0, Q128
const Q128 = 1n << 128n;

// zeroForOne arb: pays quantityIn token0, wants quantityOut token1. surplus = (in*2000 - out) << 128.
function order(searcherLast: string, quantityIn: bigint, quantityOut: bigint): ToBOrderT {
    return {
        searcher: `0x${"0".repeat(38)}${searcherLast}` as `0x${string}`,
        poolId: POOL_ID,
        zeroForOne: true,
        useInternal: false,
        quantityIn,
        quantityOut,
        validForBlock: 100n,
        signature: "0x",
    };
}

const E18 = 1_000_000_000_000_000_000n;
const A = order("a1", E18, 1_900n * E18); // surplus 100e18
const B = order("a2", E18, 1_500n * E18); // surplus 500e18 — best
const C = order("a3", E18, 2_100n * E18); // surplus -100e18 — ineligible

describe("auction rule A (price-weighted net token0)", () => {
    it("scores surplus in token1*Q128 units", () => {
        expect(scoreOrder(B, PRICE)).toBe(500n * E18 * Q128);
        expect(scoreOrder(C, PRICE)).toBe(-100n * E18 * Q128);
    });

    it("elects the greatest-surplus eligible order", () => {
        expect(electWinner([A, B, C], PRICE)?.searcher).toBe(B.searcher);
    });

    it("skips non-positive-surplus orders", () => {
        expect(electWinner([C], PRICE)).toBeNull();
    });

    it("returns null when there are no orders", () => {
        expect(electWinner([], PRICE)).toBeNull();
    });

    it("breaks ties deterministically, independent of input order", () => {
        const d = order("d1", 2n * E18, 3_900n * E18); // surplus 100e18
        const e = order("e1", 2n * E18, 3_900n * E18); // surplus 100e18, same score
        expect(scoreOrder(d, PRICE)).toBe(scoreOrder(e, PRICE));
        expect(electWinner([d, e], PRICE)?.searcher).toBe(electWinner([e, d], PRICE)?.searcher);
    });
});
