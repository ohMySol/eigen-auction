import { z } from "zod";
import type { ToBOrderT } from "@eigen-auction/shared";
import { hexBytes, hex, uintString } from "./primitives";

// Wire shape of POST /order: a searcher's EIP-712-signed arb order (ToBOrder), replacing the legacy
// EIP-191 /bid. Field order mirrors the Solidity ToBOrder struct.
export const orderSchema = z.object({
    searcher: hexBytes(20),
    poolId: hexBytes(32),
    zeroForOne: z.boolean(),
    useInternal: z.boolean(),
    quantityIn: uintString,
    quantityOut: uintString,
    validForBlock: uintString,
    signature: hex,
});

// Parse + validate an untrusted body into a typed ToBOrderT (throws ZodError -> 400 on failure).
export function parseOrderBody(body: unknown): ToBOrderT {
    return orderSchema.parse(body) as unknown as ToBOrderT;
}
