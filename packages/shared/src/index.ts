// Public entry point for @eigen-auction/shared: the pure, side-effect-free modules that both the
// backend and the demo scripts consume. `config` is deliberately NOT re-exported here — it loads
// dotenv and reads a deployment artifact at import time, so it lives behind the `/config` subpath
// (import { config } from "@eigen-auction/shared/config") to keep this barrel free of side effects.
export * from "./types";
export * from "./abi";
export * from "./poolId";
export * from "./sign";
export * from "./resultHash";
export * from "./auction";