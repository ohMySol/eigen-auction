import { z } from "zod";
import type { SignedBidT } from "../../../shared/types";
import { hexBytes, hex, uintString } from "./primitives";

// Wire shape of POST /bid: a searcher's signed offer for the block's arb right.
export const bidSchema = z.object({
    poolId: hexBytes(32),
    targetBlock: uintString,
    bidder: hexBytes(20),
    bidAmount: uintString,
    signature: hex,
});

// Parse + validate an untrusted body into a typed SignedBidT (throws ZodError -> 400 on failure).
export function parseBidBody(body: unknown): SignedBidT {
    return bidSchema.parse(body) as SignedBidT;
}
