import { defineConfig } from "vitest/config";

// One root test run across every workspace. Tests are co-located at packages/<pkg>/test/.
// shared/config.ts fail-fasts on missing env at import and reads addresses from a deployment
// artifact; point it at the committed fixture so pure modules that transitively import config load.
// No test makes real RPC/Redis calls with these.
export default defineConfig({
    test: {
        include: ["packages/*/test/**/*.test.ts"],
        env: {
            RPC_URL: "http://127.0.0.1:8545",
            CHAIN_ID: "31337",
            REDIS_URL: "redis://127.0.0.1:6379",
            DEPLOYMENTS_DIR: "packages/shared/test/fixtures/deployments",
        },
    },
});
