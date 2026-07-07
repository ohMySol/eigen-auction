import type { Address, Hex } from "viem";
import type { ToBOrderT } from "@eigen-auction/shared";
import { recoverToBOrderSigner } from "@eigen-auction/shared";
import { ValidationError } from "../verify";

// Collaborators injected so the service stays unit-testable and transport-free.
export interface OrderServiceDeps {
    settler: Address;
    chainId: number;
    expectedPoolId: Hex;
    addOrder: (order: ToBOrderT) => Promise<void>;
}

// Application layer for arb orders: reject anything the Settler would (wrong pool, zero-sized, forged
// signature), then store it for the block's seal. Mirrors the Settler's own arb checks so the relay
// never seals an order that would revert on settle.
export class OrderService {
    constructor(private readonly deps: OrderServiceDeps) {}

    async submit(order: ToBOrderT): Promise<void> {
        if (order.poolId.toLowerCase() !== this.deps.expectedPoolId.toLowerCase()) {
            throw new ValidationError("order targets the wrong pool");
        }
        if (order.quantityIn === 0n && order.quantityOut === 0n) {
            throw new ValidationError("order has zero quantities");
        }
        const signer = await recoverToBOrderSigner(this.deps.settler, this.deps.chainId, order);
        if (signer.toLowerCase() !== order.searcher.toLowerCase()) {
            throw new ValidationError("invalid signature: signer does not match searcher");
        }
        await this.deps.addOrder(order);
    }
}
