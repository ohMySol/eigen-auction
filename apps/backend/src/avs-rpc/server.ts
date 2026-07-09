import express from "express";
import Redis from "ioredis";
import type { Address } from "viem";
import { config, poolKey, publicClient } from "@eigen-auction/shared/config";
import { getPoolId } from "@eigen-auction/shared";
import { settlerAbi } from "@eigen-auction/shared";
import { RedisMempool } from "./mempool";
import { RedisOrderStore } from "./order-mempool";
import { IntentService } from "./services/intent.service";
import { OrderService } from "./services/order.service";
import { buildRouter } from "./routes";
import { errorHandler } from "./middleware/error";

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
  app.use(
    buildRouter({
      intentService,
      orderService,
      auction: {
        orders: () => orderStore.all(),
        intents: () => mempool.all(),
        // The relay stamps one clearing price per block. The demo uses the configured
        // fixed price; a live price feed would replace this getter.
        humanPrice: () => config.fixedPrice,
        decimals0: config.decimals0,
        decimals1: config.decimals1,
      },
      isNonceUsed,
    }),
  );
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
