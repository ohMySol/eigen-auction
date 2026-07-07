import type { Request, Response, NextFunction } from "express";
import { parseOrderBody } from "../schemas/order.schema";
import type { OrderService } from "../services/order.service";

// Thin HTTP adapter for POST /order: parse+validate the body, delegate to the service, shape response.
export const makeOrderController =
    (service: OrderService) =>
    async (req: Request, res: Response, next: NextFunction): Promise<void> => {
        try {
            const order = parseOrderBody(req.body);
            await service.submit(order);
            res.status(202).json({ ok: true });
        } catch (err) {
            next(err);
        }
    };
