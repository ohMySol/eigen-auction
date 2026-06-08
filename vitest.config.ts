import { defineConfig } from "vitest/config";

// Tests live in a mirror tree under src/test/ (not co-located with source).
// shared/config.ts fail-fasts on missing env at import and reads addresses from a deployment
// artifact; point it at the committed fixture so pure modules that transitively import config load.
// No test makes real RPC/Redis calls with these.
export default defineConfig({
    test: {
        include: ["src/test/**/*.test.ts"],
        env: {
            RPC_URL: "http://127.0.0.1:8545",
            CHAIN_ID: "31337",
            REDIS_URL: "redis://127.0.0.1:6379",
            DEPLOYMENTS_DIR: "src/test/fixtures/deployments",
        },
    },
});
