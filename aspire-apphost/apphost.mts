// Aspire TypeScript AppHost — local orchestrator for the long-running services (redis + relay +
// aggregator + N operators + frontend). The chain setup (anvil, deploy, fund, register, drive-round)
// stays in Make/forge; run those first, then `aspire run`.
import { createBuilder } from './.aspire/modules/aspire.mjs';
import { fileURLToPath } from 'node:url';

// Repo root is one level up from aspire-apphost/.
const root = fileURLToPath(new URL('..', import.meta.url));

// Environment selection. Default: local.
//   - local: parse the repo-root .env into process.env, and run the whole stack including the dev operator nodes.
//   - anything else (staging/production): do NOT read a dev file — every value comes from the real
//   environment the platform/secret store injects, and operators are NOT hosted here.
const isLocal = (process.env.APP_ENV ?? "local") === "local";
if (isLocal) process.loadEnvFile(`${root}.env`);

// One config source: process.env — populated from .env locally, or by the platform in prod. Reading
// through a getter keeps the type as string (process.env values are string | undefined).
const get = (k: string): string => process.env[k] ?? "";
const deployments = `${root}deployments`; // absolute; relay + Go binaries all read DEPLOYMENTS_DIR

// Chain env shared by the relay and both Go binaries.
const chain = { 
    RPC_URL: get("RPC_URL"), 
    WS_URL: get("WS_URL"), 
    CHAIN_ID: get("CHAIN_ID"), 
    DEPLOYMENTS_DIR: deployments 
};

// Aspire's built-in `withEnvironment` sets one var at a time and returns the builder. This helper takes
// a whole map and applies them in a loop, so the shared `chain` vars aren't repeated per service.
//   - res:  what addGoApp(...)/addNodeApp(...) returns.
//   - vars: env vars as a plain object, e.g. { RPC_URL: "...", CHAIN_ID: "1" }.
function withEnv<T extends { withEnvironment(k: string, v: string): T }>(res: T, vars: Record<string, string>): T {
    for (const [k, v] of Object.entries(vars)) res = res.withEnvironment(k, v ?? '');
    return res;
}

const builder = await createBuilder();

// The one secret prod value the apphost carries: the aggregator's signing key. As an Aspire
// secret parameter, `aspire publish` maps it to the target's secret store instead of including it into a
// manifest; locally it's seeded from .env. Non-secret config stays plain env (12-factor). Operator keys
// are NOT parameters — they're local-only anvil dev keys (below), or, in prod, each operator's own.
const aggregatorPk = await builder.addParameter("aggregator-pk", { value: get("AGGREGATOR_PK"), secret: true });

// NOTE: app working-dir paths below are relative to THIS AppHost folder (aspire-apphost/), not the repo
// root — hence the `../` prefixes. (The .env/deployments paths above use `root`, already one level up.)

/* ------------------- Infra ------------------- */

// Plain redis container — NOT the `addRedis` integration, which enables TLS + a generated password
// that a plain `redis://` client (ioredis) can't speak. Pinned to host 6379 (isProxied:false = direct
// mapping, no DCP proxy): the out-of-Aspire scripts (drive-round/post-batch/approve, run via `make`)
// read a fixed REDIS_URL from .env, so redis must sit at a known address the relay AND they both use.
const redis = (await builder.addContainer("redis", "redis:7-alpine"))
    .withEndpoint({ 
        port: 6379, 
        targetPort: 6379, 
        scheme: "tcp", 
        name: "tcp", 
        isProxied: false 
    });

/* ------------------- Relay (TS) ------------------- */

// The seal endpoint: searchers/users POST orders/intents; operators GET the sealed set per block.
// It listens on INTENT_PORT (8088, injected below), which FEED_URL and VITE_INTENT_URL both point at.
// Run via its ts-node script (`pnpm run start-server`), NOT `node server.ts`: the code uses
// extensionless imports + TS parameter properties + workspace .ts deps, all of which Node's native
// type-stripping rejects — ts-node handles them. addExecutable's working dir is relative to this folder.
const relay = withEnv(
    (await builder.addExecutable("avs-rpc", "pnpm", "../apps/backend", ["run", "start-server"]))
        // App listens directly on 8088 (INTENT_PORT); no DCP proxy (proxying a non-container with
        // port==targetPort is rejected). Others reach it at the fixed FEED_URL, not via discovery.
        .withHttpEndpoint({ targetPort: 8088, isProxied: false })
        .waitFor(redis),
    {
        ...chain,
        REDIS_URL: get("REDIS_URL"),
        INTENT_PORT: get("INTENT_PORT"),
        PRICE_SOURCE: get("PRICE_SOURCE"),
        FIXED_PRICE: get("FIXED_PRICE")
    },
);

/* ------------------- Aggregator (Go) ------------------- */

// Collects operator BLS sigs, aggregates over the registry snapshot, submits commitWinner. Binds
// LISTEN_ADDR (:9090) itself; operators reach it via AGGREGATOR_URL — both fixed in .env, so no Aspire
// endpoint is needed. AGGREGATOR_PK comes from the secret parameter, not the plain env map.
const aggregator = withEnv(
    (await builder.addGoApp("aggregator", "../avs/cmd/aggregator")).waitFor(relay),
    { ...chain, LISTEN_ADDR: get("LISTEN_ADDR") },
).withEnvironment("AGGREGATOR_PK", aggregatorPk); // aggregatorPk is a ParameterResource (the Aspire secret parameter), not a string.

/* ------------------- Operators (Go) — LOCAL/FORK ONLY ------------------- */

// One addGoApp per keyset — NOT Aspire replicas, which would share config; each operator needs a
// distinct OPERATOR_PK + BLS_PRIVATE_KEY. operator-1 uses the registered keys from .env; 2 & 3 use
// anvil dev keys (register them first: fund-operator → fund-operator-stake → register).
// Added only when APP_ENV=local: on testnet/mainnet, operators are independent third parties, so the
// apphost hosts none of them.
if (isLocal) {
    const operators = [
        { name: "operator-1", pk: get("OPERATOR_PK"), bls: get("BLS_PRIVATE_KEY") },
        { name: "operator-2", pk: "0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba", bls: "2" },
        { name: "operator-3", pk: "0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e", bls: "3" },
    ];
    for (const o of operators) {
        withEnv(
            (await builder.addGoApp(o.name, "../avs/cmd/operator")).waitFor(aggregator),
            { 
                ...chain, 
                FEED_URL: get("FEED_URL"), 
                AGGREGATOR_URL: get("AGGREGATOR_URL"), 
                OPERATOR_PK: o.pk, 
                BLS_PRIVATE_KEY: o.bls 
            },
        );
    }
} else {
    console.log(`[apphost] APP_ENV=${process.env.APP_ENV} — skipping operator nodes; run them as independent services.`);
}

/* ------------------- Frontend (Vite) ------------------- */

withEnv(
    (await builder.addViteApp("frontend", "../apps/frontend"))
        .waitFor(relay)
        .withPnpm({ install: false }),
    { 
        VITE_CHAIN_ID: get("VITE_CHAIN_ID"), 
        VITE_RPC_URL: get("VITE_RPC_URL"), 
        VITE_INTENT_URL: get("VITE_INTENT_URL") 
    },
);

await builder.build().run();
