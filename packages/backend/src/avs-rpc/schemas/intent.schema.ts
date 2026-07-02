import { z } from "zod";
import type { SwapIntentT } from "@eigen-auction/shared";
import { hexBytes, hex, uintString } from "./primitives";

// Wire shape of POST /intent. Validates every field at the boundary, then transforms the
// numeric strings into the bigint-typed SwapIntentT the rest of the backend works with.
export const intentSchema = z.object({
    user: hexBytes(20),
    poolId: hexBytes(32),
    zeroForOne: z.boolean(),
    amountIn: uintString,
    minAmountOut: uintString,
    nonce: uintString,
    deadline: uintString,
    signature: hex,
});

// Parse-and-validate an untrusted request body into a typed SwapIntentT.
// Throws ZodError on any malformed/missing field; the error middleware maps that to a 400.
export function parseIntentBody(body: unknown): SwapIntentT {
    return intentSchema.parse(body) as SwapIntentT;
}
