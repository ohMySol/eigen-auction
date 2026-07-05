import { describe, it, expect } from "vitest";
import { privateKeyToAccount } from "viem/accounts";
import { signIntent, signToBOrder, recoverToBOrderSigner, orderDigest, INTENT_TYPES, intentDomain } from "../src/sign";
import type { ToBOrderT } from "../src/types";

const account = privateKeyToAccount("0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d");
const settler = "0x0000000000000000000000000000000000000001";

// Shared golden vector for the arb-order EIP-712 digest — the Go operator reproduces this exact
// literal (avs/internal/consensus/orders_test.go). settler/chainId are fixed to match the Go test.
const ORDER_SETTLER = "0x000000000000000000000000000000000000dead";
const ORDER: Omit<ToBOrderT, "signature"> = {
    searcher: "0x00000000000000000000000000000000000000a1",
    poolId: "0x1111111111111111111111111111111111111111111111111111111111111111",
    zeroForOne: true,
    useInternal: false,
    quantityIn: 1_050_000_000_000_000_000n,
    quantityOut: 1_000_000_000_000_000_000n,
    validForBlock: 100n,
};

describe("signIntent Tests", () => {
    it("signIntent produce a 65 byte EIP-712 signature", async () => {
        const signature = await signIntent(
            account, 
            settler, 
            31337,
            {
                user: account.address,
                poolId: ("0x" + "11".repeat(32)) as `0x${string}`,
                zeroForOne: true,
                useInternal: false,
                amountIn: 10n ** 18n,
                minAmountOut: 1n, 
                nonce: 7n, 
                deadline: 9999999999n,
            });

            expect(signature).toMatch(/^0x[0-9a-f]{130}$/);
    });

    it("signIntent uses the exact contract domain + type", () => {
        expect(intentDomain(settler, 31337).name).toBe("EigenAuction Settler");
        expect(INTENT_TYPES.SwapIntent.length).toBe(8);
    });
})

describe("ToBOrder EIP-712", () => {
    it("orderDigest matches the shared golden vector", () => {
        expect(orderDigest(ORDER, ORDER_SETTLER, 31337)).toBe(
            "0xd094e0848e3c0dfcf82febe4aec69df2393ebb158ce6338ec15ef96e379ac9a4",
        );
    });

    it("sign then recover round-trips to the searcher", async () => {
        const order: ToBOrderT = { ...ORDER, searcher: account.address, signature: "0x" };
        const { signature: _omit, ...unsigned } = order;
        order.signature = await signToBOrder(account, ORDER_SETTLER, 31337, unsigned);
        expect((await recoverToBOrderSigner(ORDER_SETTLER, 31337, order)).toLowerCase()).toBe(
            account.address.toLowerCase(),
        );
    });
})