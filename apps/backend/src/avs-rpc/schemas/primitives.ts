import { z } from "zod";

// 0x-prefixed hex of a fixed byte length (e.g. 20-byte address, 32-byte poolId).
export const hexBytes = (bytes: number) =>
    z.string().regex(new RegExp(`^0x[0-9a-fA-F]{${bytes * 2}}$`), `expected ${bytes}-byte hex`);

// Any 0x-prefixed hex string of even length (signature length is checked on-chain).
export const hex = z.string().regex(/^0x[0-9a-fA-F]*$/, "expected 0x-prefixed hex");

// A non-negative integer delivered as a decimal string, coerced to bigint.
// JSON has no bigint, so clients send uint fields as strings.
export const uintString = z
    .string()
    .regex(/^\d+$/, "expected a non-negative integer string")
    .transform((s) => BigInt(s));
