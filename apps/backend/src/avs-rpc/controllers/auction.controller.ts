import type { Request, Response, NextFunction } from "express";
import type { ToBOrderT, SwapIntentT } from "@eigen-auction/shared";
import { buildSealedSet, REF_OFFSET } from "../seal";

export interface AuctionControllerDeps {
    // Non-draining reads: every operator must receive the identical sealed set for a block.
    orders: () => Promise<ToBOrderT[]>;
    intents: () => Promise<SwapIntentT[]>;
    // The block's clearing price (currency1 whole units per 1 currency0 whole unit), read at the
    // deterministic referenceBlockNumber so every operator stamps the identical value.
    humanPrice: (referenceBlock: number) => Promise<number>;
    decimals0: number;
    decimals1: number;
}

// GET /auction/:block — seals and serves the block's canonical order+intent set. Orders are scoped to
// the target block by validForBlock; intents (deadline-scoped, not block-scoped) are all included.
export const makeAuctionController =
    (deps: AuctionControllerDeps) =>
    async (req: Request, res: Response, next: NextFunction): Promise<void> => {
        try {
            const targetBlock = Number(req.params.block);
            if (!Number.isInteger(targetBlock) || targetBlock <= 0) {
                res.status(400).json({ error: "block must be a positive integer" });
                return;
            }
            // Read the clearing price at the same referenceBlockNumber buildSealedSet stamps, so the
            // price and the reference block agree (and are identical for every operator).
            const referenceBlock = targetBlock - REF_OFFSET;
            const [allOrders, intents, humanPrice] = await Promise.all([
                deps.orders(),
                deps.intents(),
                deps.humanPrice(referenceBlock),
            ]);
            const orders = allOrders.filter((o) => o.validForBlock === BigInt(targetBlock));
            res.json(
                buildSealedSet({
                    targetBlock,
                    orders,
                    intents,
                    humanPrice,
                    decimals0: deps.decimals0,
                    decimals1: deps.decimals1,
                }),
            );
        } catch (err) {
            next(err);
        }
    };
