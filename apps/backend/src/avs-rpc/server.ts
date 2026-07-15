import express from "express";
import fs from "node:fs";
import path from "node:path";
import Redis from "ioredis";
import type { Address } from "viem";
import { config, poolKey, publicClient } from "@eigen-auction/shared/config";
import { getPoolId } from "@eigen-auction/shared";
import { settlerAbi, stateViewAbi } from "@eigen-auction/shared";
import { RedisMempool } from "./mempool";
import { RedisOrderStore } from "./order-mempool";
import { IntentService } from "./services/intent.service";
import { OrderService } from "./services/order.service";
import { buildRouter } from "./routes";
import { errorHandler } from "./middleware/error";

// V4 sqrtPriceX96 --> human price: currency1 whole units per 1 currency0 whole unit (the convention
// clearingPriceX128 expects). (sqrtP / 2^96)^2 is currency1-raw per currency0-raw; scale by the
// decimal difference to whole units.
function sqrtPriceToHuman(sqrtPriceX96: bigint, decimals0: number, decimals1: number): number {
  const ratio = Number(sqrtPriceX96) / 2 ** 96;
  return ratio * ratio * 10 ** (decimals0 - decimals1);
}

// Public ingress for the auction: searchers/users POST signed intents here; valid ones are
// pushed to Redis for the operator to drain each block. Composition root — wires infra
// (Redis, RPC) into the service, mounts the router, then starts listening.
async function main(): Promise<void> {
  const redis = new Redis(config.redisUrl);
  const poolId = getPoolId(poolKey);
  const mempool = new RedisMempool(redis, poolId);
  const orderStore = new RedisOrderStore(redis, poolId);

  // Live nonce-bitmap read against the Settler, injected into the service + status endpoint.
  const isNonceUsed = (user: Address, nonce: bigint): Promise<boolean> =>
    publicClient.readContract({
      address: config.settler,
      abi: settlerAbi,
      functionName: "isNonceUsed",
      args: [user, nonce],
    });

  const intentService = new IntentService({
    settler: config.settler,
    chainId: config.chainId,
    expectedPoolId: poolId,
    add: (intent) => mempool.add(intent),
    isNonceUsed,
  });

  const orderService = new OrderService({
    settler: config.settler,
    chainId: config.chainId,
    expectedPoolId: poolId,
    addOrder: (order) => orderStore.addOrder(order),
  });

  const app = express();
  app.use(express.json());

  // Serve the built SPA when it's baked into the image (publish: docker/Dockerfile.backend copies it to
  // ./static). In local dev the Vite dev server serves the frontend instead, so this dir is absent and
  // both handlers below are simply never registered.
  const staticDir = path.resolve("static");
  const serveSpa = fs.existsSync(staticDir);
  if (serveSpa) app.use(express.static(staticDir));

  app.use(
    buildRouter({
      intentService,
      orderService,
      auction: {
        orders: () => orderStore.all(),
        intents: () => mempool.all(),
        // Clearing price = the pool's live mid, read from StateView.getSlot0 at the block's
        // referenceBlockNumber. Pinning to that fixed past block makes it deterministic (every operator
        // stamps the identical price regardless of when it fetches); tracking the live pool keeps the
        // batch solvent as prior settles move the price — a fixed price goes stale --> Settler_BatchInsolvent.
        humanPrice: (referenceBlock: number) =>
          publicClient
            .readContract({
              address: config.stateView,
              abi: stateViewAbi,
              functionName: "getSlot0",
              args: [poolId],
              blockNumber: BigInt(referenceBlock),
            })
            .then(([sqrtPriceX96]) => sqrtPriceToHuman(sqrtPriceX96, config.decimals0, config.decimals1)),
        decimals0: config.decimals0,
        decimals1: config.decimals1,
      },
      isNonceUsed,
    }),
  );
  // SPA client-side routing: any unmatched GET falls back to index.html. A plain middleware (not a
  // wildcard route) — Express 5 rejects the bare "*" path. Registered after the API router so real
  // endpoints win; only active when the static bundle is present.
  if (serveSpa) {
    app.use((req, res, next) => {
      if (req.method !== "GET") return next();
      res.sendFile(path.join(staticDir, "index.html"));
    });
  }

  app.use(errorHandler);

  const server = app.listen(config.intentPort, () =>
    console.log(`avs-rpc listening on :${config.intentPort} (pool ${poolId})`),
  );

  // Close Redis and the HTTP listener cleanly on container stop so no intent is half-written.
  const shutdown = async () => {
    server.close();
    await redis.quit();
    process.exit(0);
  };
  process.on("SIGTERM", shutdown);
  process.on("SIGINT", shutdown);
}

main().catch((err) => {
  console.error("avs-rpc failed to start:", err);
  process.exit(1);
});
