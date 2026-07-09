import { describe, it, expect } from "vitest";
import type { ToBOrderT, SwapIntentT } from "@eigen-auction/shared";
import { clearingPriceX128, buildSealedSet } from "../../src/avs-rpc/seal";

const POOL_ID = ("0x" + "11".repeat(32)) as `0x${string}`;

describe("clearingPriceX128 (frozen derivation)", () => {
    it("stamps currency1-raw per currency0-raw in Q128, 2% solvency discount below mid", () => {
        // 0.0005 WETH per USDC → mid = 5e8 WETH-raw per USDC-raw; minus a 2% fee/slippage discount → 4.9e8.
        expect(clearingPriceX128(0.0005, 6, 18)).toBe(490_000_000n << 128n);
    });

    it("is a pure function of price + decimals (deterministic across operators)", () => {
        expect(clearingPriceX128(0.0005, 6, 18)).toBe(clearingPriceX128(0.0005, 6, 18));
    });
});

describe("buildSealedSet wire shape", () => {
    const order: ToBOrderT = {
        searcher: "0x00000000000000000000000000000000000000a1",
        poolId: POOL_ID,
        zeroForOne: true,
        useInternal: false,
        quantityIn: 1_050_000_000_000_000_000n,
        quantityOut: 1_000_000_000_000_000_000n,
        validForBlock: 100n,
        signature: "0xabcd",
    };
    const intent: SwapIntentT = {
        user: "0x00000000000000000000000000000000000000b1",
        poolId: POOL_ID,
        zeroForOne: false,
        useInternal: true,
        amountIn: 5_000_000_000_000_000_000n,
        minAmountOut: 4_900_000_000_000_000_000n,
        nonce: 7n,
        deadline: 1_000_000n,
        signature: "0xdead",
    };

    it("encodes bigints as strings, blocks as numbers, and derives the reference block", () => {
        const sealed = buildSealedSet({
            targetBlock: 100,
            orders: [order],
            intents: [intent],
            humanPrice: 0.0005,
            decimals0: 6,
            decimals1: 18,
        });

        expect(sealed.targetBlock).toBe(100);
        expect(sealed.referenceBlockNumber).toBe(99); // target - REF_OFFSET
        expect(sealed.clearingPriceX128).toBe((490_000_000n << 128n).toString());
        expect(sealed.orders[0].quantityIn).toBe("1050000000000000000");
        expect(sealed.orders[0].validForBlock).toBe(100);
        expect(sealed.intents[0].nonce).toBe(7);
        expect(sealed.intents[0].minAmountOut).toBe("4900000000000000000");
    });
});
