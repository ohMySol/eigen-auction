import { describe, it, expect } from "vitest";
import { toBStructHash, computeResultHash, type IntentTermsT } from "../src/resultHash";
import type { ToBOrderT } from "../src/types";

// Golden vectors shared with src/contracts/test/unit/ResultHashVectors.t.sol. The Solidity side
// generates them from the real Settler.computeResultHash and asserts the same literals; asserting
// them here proves the TS reference is byte-identical to the contract. Keep inputs in lockstep with
// the .t.sol fixtures — signatures are omitted because they never enter a struct hash.
const POOL_ID = "0x1111111111111111111111111111111111111111111111111111111111111111" as const;
const PRICE = 2000n << 128n;

const arb: ToBOrderT = {
    searcher: "0x00000000000000000000000000000000000000a1",
    poolId: POOL_ID,
    zeroForOne: true,
    useInternal: false,
    quantityIn: 1_050_000_000_000_000_000n, // 1.05e18
    quantityOut: 1_000_000_000_000_000_000n, // 1e18
    validForBlock: 100n,
    signature: "0x",
};

const intents: IntentTermsT[] = [
    {
        user: "0x00000000000000000000000000000000000000b1",
        poolId: POOL_ID,
        zeroForOne: false,
        useInternal: true,
        amountIn: 5_000_000_000_000_000_000n, // 5e18
        minAmountOut: 4_900_000_000_000_000_000n, // 4.9e18
        nonce: 7n,
        deadline: 1_000_000n,
    },
    {
        user: "0x00000000000000000000000000000000000000b2",
        poolId: POOL_ID,
        zeroForOne: true,
        useInternal: false,
        amountIn: 2_000_000_000_000_000_000n, // 2e18
        minAmountOut: 1_900_000_000_000_000_000n, // 1.9e18
        nonce: 8n,
        deadline: 2_000_000n,
    },
];

const emptyArb: ToBOrderT = { ...arb, quantityIn: 0n, quantityOut: 0n };

describe("resultHash reference matches Solidity", () => {
    it("toBStructHash", () => {
        expect(toBStructHash(arb)).toBe("0x623d60f3f55e097ac6780b2e8b72874564238438fdd60c39df059e5a7506a0fb");
    });

    it("computeResultHash with arb", () => {
        expect(computeResultHash(arb, PRICE, intents)).toBe(
            "0xe7c8f352536e6767c8d9e173dbaa5ed772196e83f2b75dc76e084629119a3f80",
        );
    });

    it("computeResultHash with no arb (all-zero order hashes to bytes32(0))", () => {
        expect(computeResultHash(emptyArb, PRICE, intents)).toBe(
            "0x7c8574d6b61317609623f598d388490de3f68f37cdd8ff1494c6ec4a27472cb8",
        );
    });
});
