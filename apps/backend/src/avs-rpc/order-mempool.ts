import type Redis from "ioredis";
import type { ToBOrderT } from "@eigen-auction/shared";

// One Redis list per pool for searcher arb orders (ToBOrders), separate from the intent queue. Unlike
// the intent queue, orders are READ (not drained) by the seal endpoint: every operator must receive the
// identical sealed set for a block, so the relay serves the same bytes to all and lets `validForBlock`
// scope each order to exactly one block.
const orderKey = (poolId: string) => `orders:${poolId.toLowerCase()}`;

// bigint fields are encoded as decimal strings for JSON (matching the Go feed wire contract).
export function serializeOrder(o: ToBOrderT): string {
    return JSON.stringify({
        ...o,
        quantityIn: o.quantityIn.toString(),
        quantityOut: o.quantityOut.toString(),
        validForBlock: o.validForBlock.toString(),
    });
}

export function deserializeOrder(raw: string): ToBOrderT {
    const o = JSON.parse(raw);
    return {
        ...o,
        quantityIn: BigInt(o.quantityIn),
        quantityOut: BigInt(o.quantityOut),
        validForBlock: BigInt(o.validForBlock),
    };
}

export class RedisOrderStore {
    constructor(private readonly redis: Redis, private readonly poolId: string) {}

    async addOrder(order: ToBOrderT): Promise<void> {
        await this.redis.rpush(orderKey(this.poolId), serializeOrder(order));
    }

    // Non-draining read of every stored order; the seal endpoint filters to the target block.
    async all(): Promise<ToBOrderT[]> {
        const items = await this.redis.lrange(orderKey(this.poolId), 0, -1);
        return items.map(deserializeOrder);
    }
}
