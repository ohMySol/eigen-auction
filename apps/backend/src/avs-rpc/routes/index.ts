import { Router } from "express";
import { type Address } from "viem";
import { healthController } from "../controllers/health.controller";
import { makeIntentController } from "../controllers/intent.controller";
import { makeOrderController } from "../controllers/order.controller";
import { makeAuctionController, type AuctionControllerDeps } from "../controllers/auction.controller";
import { makeStatusController } from "../controllers/status.controller";
import type { IntentService } from "../services/intent.service";
import type { OrderService } from "../services/order.service";

// Wires HTTP routes to their controllers. New endpoints slot in here without touching the bootstrap.
export function buildRouter(deps: {
    intentService: IntentService;
    orderService: OrderService;
    auction: AuctionControllerDeps;
    isNonceUsed: (user: Address, nonce: bigint) => Promise<boolean>;
}): Router {
    const router = Router();

    router.get("/health", healthController);
    router.post("/intent", makeIntentController(deps.intentService));
    router.post("/order", makeOrderController(deps.orderService));
    router.get("/auction/:block", makeAuctionController(deps.auction));
    router.get("/status", makeStatusController(deps.isNonceUsed));

    return router;
}
