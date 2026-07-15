// Aspire TypeScript AppHost.
//   - `aspire run`     : orchestrates the whole local stack (redis + relay + aggregator + N operators + frontend).
//   - `aspire publish` : generates the docker-compose DEPLOY stack into aspire-output/. That stack is the
//                        user-facing services (redis + relay + frontend), matching what the hand-written
//                        compose shipped; the Go AVS runs on the AVS/operator side (operators are independent third parties,
//                        the aggregator is run by the AVS coordinator), so it is added only for local runs.
// Chain setup (anvil, deploy, fund, register, drive-round) stays in Make/forge.
import { createBuilder, refExpr, EndpointProperty } from './.aspire/modules/aspire.mjs';
import { fileURLToPath } from 'node:url';

// Repo root is one level up from aspire-apphost/.
const root = fileURLToPath(new URL('..', import.meta.url));

const builder = await createBuilder();

// Run vs publish. Config differs between the two: locally everything is on the host at fixed localhost
// ports and in the compose, services reach each other by service name and read config from the image/env.
const publishing = await (await builder.executionContext()).isPublishMode();
const isLocal = !publishing && (process.env.APP_ENV ?? "local") === "local";
if (isLocal || publishing) process.loadEnvFile(`${root}.env`);

// One config source: process.env. Reading through a getter keeps the type as string.
const get = (k: string): string => process.env[k] ?? "";
// Deployment artifact: a host absolute path locally; the baked container path in the compose image.
const deploymentsDir = publishing ? "/app/deployments" : `${root}deployments`;

// Chain env shared by the relay and (locally) the Go binaries.
const chain = { 
    RPC_URL: get("RPC_URL"), 
    WS_URL: get("WS_URL"), 
    CHAIN_ID: get("CHAIN_ID"), 
    DEPLOYMENTS_DIR: deploymentsDir 
};

// withEnvironment sets one var at a time; apply a whole map.
function withEnv<T extends { withEnvironment(k: string, v: string): T }>(res: T, vars: Record<string, string>): T {
    for (const [k, v] of Object.entries(vars)) res = res.withEnvironment(k, v ?? '');
    return res;
}

// Publish target: `aspire publish` emits a docker-compose.yaml into aspire-output/. `aspire run` ignores it.
await builder.addDockerComposeEnvironment("docker-compose");

/* ------------------- Infra ------------------- */

// Plain redis container (NOT the addRedis integration — it enables TLS + a password a plain `redis://`
// client can't speak). Pinned to host 6379 so the out-of-Aspire scripts (drive-round/post-batch, run via
// make) reach it too. REDIS_URL resolves per context: redis://127.0.0.1:6379 locally, redis://redis:6379
// in the compose — so nothing hardcodes the host.
const redis = (await builder.addContainer("redis", "redis:7-alpine"))
    .withEndpoint({ port: 6379, targetPort: 6379, scheme: "tcp", name: "tcp", isProxied: false });
const redisEndpoint = await redis.getEndpoint("tcp");
const redisUrl = refExpr`redis://${await redisEndpoint.property(EndpointProperty.HostAndPort)}`;

/* ------------------- Relay (TS) ------------------- */

// Local: runs via its ts-node script (`pnpm run start-server`) — bare `node` chokes on the code's
// parameter properties + workspace .ts deps. Publish: built from the existing Dockerfile (which bakes
// deployments/ + `CMD start-server`), since Aspire can't containerize a raw executable. That image also
// builds + serves the Vite SPA (see docker/Dockerfile.backend), so the relay is the single web tier in
// the compose — hence the VITE_* build args here.
const relay = withEnv(
    (await builder.addExecutable("avs-rpc", "pnpm", "../apps/backend", ["run", "start-server"]))
        .withHttpEndpoint({ targetPort: 8088, isProxied: false })
        .waitFor(redis)
        .publishAsDockerFile(async (c) => {
            await c.withDockerfile("..", { dockerfilePath: "docker/Dockerfile.backend" });
            await c.withBuildArg("VITE_CHAIN_ID", get("VITE_CHAIN_ID"));
            await c.withBuildArg("VITE_RPC_URL", get("VITE_RPC_URL"));
            await c.withBuildArg("VITE_INTENT_URL", get("VITE_INTENT_URL"));
        }),
    { 
        ...chain, 
        INTENT_PORT: get("INTENT_PORT"), 
        PRICE_SOURCE: get("PRICE_SOURCE"), 
        FIXED_PRICE: get("FIXED_PRICE") 
    },
).withEnvironment("REDIS_URL", redisUrl);

/* ------------------- Go AVS — local runs only ------------------- */

// The aggregator + operators are the decentralized AVS role: on a real deploy they run on independent
// operator infrastructure, not in this compose. So they are added only when NOT publishing.
if (!publishing) {
    // The one secret prod value: the aggregator's signing key, as an Aspire secret parameter.
    const aggregatorPk = await builder.addParameter("aggregator-pk", { value: get("AGGREGATOR_PK"), secret: true });

    const aggregator = withEnv(
        (await builder.addGoApp("aggregator", "../avs/cmd/aggregator")).waitFor(relay),
        { ...chain, LISTEN_ADDR: get("LISTEN_ADDR") },
    ).withEnvironment("AGGREGATOR_PK", aggregatorPk);

    // One addGoApp per keyset — each operator needs a distinct OPERATOR_PK + BLS_PRIVATE_KEY. operator-1
    // uses the registered keys from .env; 2 & 3 use anvil dev keys (register first: fund-operator →
    // fund-operator-stake → register). Only when APP_ENV=local (default) — on testnet/mainnet, operators
    // are independent third parties.
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
    }
}

/* ------------------- Frontend (Vite) ------------------- */

// Local only: a Vite dev server (HMR) with VITE_* from env. In publish there is NO separate frontend
// resource — the relay image builds the SPA and serves it as ./static (single web container), so adding
// a standalone Vite app here would just produce a build-only container the compose pipeline drops.
if (!publishing) {
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
}

await builder.build().run();
