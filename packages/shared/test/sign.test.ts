import { describe, it, expect } from "vitest";
import { privateKeyToAccount } from "viem/accounts";
import { signIntent, INTENT_TYPES, intentDomain } from "../src/sign";

const account = privateKeyToAccount("0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d");
const settler = "0x0000000000000000000000000000000000000001";

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