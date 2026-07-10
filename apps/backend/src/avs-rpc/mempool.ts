import type Redis from "ioredis";
import type { SwapIntentT } from "@eigen-auction/shared";

// One Redis list per pool. Lower-cased so the producer and consumer never disagree on the key.
const listKey = (poolId: string) => `intents:${poolId.toLowerCase()}`;

// JSON cannot represent bigint, so the four uint fields are encoded as decimal strings.
export function serializeIntent(intent: SwapIntentT): string {
    return JSON.stringify({
        ...intent,
        amountIn: intent.amountIn.toString(),
        minAmountOut: intent.minAmountOut.toString(),
        nonce: intent.nonce.toString(),
        deadline: intent.deadline.toString(),
    });
}

// Inverse of serializeIntent: the decimal strings are parsed back into bigint.
export function deserializeIntent(raw: string): SwapIntentT {
    const o = JSON.parse(raw);
    return {
        ...o,
        amountIn: BigInt(o.amountIn),
        minAmountOut: BigInt(o.minAmountOut),
        nonce: BigInt(o.nonce),
        deadline: BigInt(o.deadline),
    };
}

// Redis-backed queue decoupling ingress from sealing: the relay RPUSHes validated intents, and the
// seal endpoint reads them per block.
export class RedisMempool {
    constructor(private readonly redis: Redis, private readonly poolId: string) {}

    // Append a validated intent to the tail of the pool's queue.
    async add(intent: SwapIntentT): Promise<void> {
        await this.redis.rpush(listKey(this.poolId), serializeIntent(intent));
    }

    // Non-draining read for the seal endpoint: every operator must see the same pending intents for a
    // block, so the relay serves them without removing them.
    async all(): Promise<SwapIntentT[]> {
        const items = await this.redis.lrange(listKey(this.poolId), 0, -1);
        return items.map(deserializeIntent);
    }
}
