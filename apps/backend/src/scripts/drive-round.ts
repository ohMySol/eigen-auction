// Orchestrates one same-block auction round on the fork. Because commitWinner and settle are both
// keyed to block.number on-chain, they must land in the SAME block — on mainnet that's a Flashbots
// bundle; this is its anvil equivalent: disable automine, post a batch, wait for the operator's settle
// and the aggregator's commit to queue in the mempool, then mine exactly one block so both execute
// together (commit first, by its higher tip). Finally report the commitment + each tx's outcome.
//
// Prereqs: deploy-fork + register done; redis + start-server + start-aggregator + start-operator-go running.
// Run: make drive-round
import "dotenv/config";
import Redis from "ioredis";
import { config, poolKey, publicClient } from "@eigen-auction/shared/config";
import { getPoolId, taskManagerAbi } from "@eigen-auction/shared";
import { postBatch } from "./post-batch";
import { reportRound } from "./results";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// Raw JSON-RPC for the anvil admin methods viem doesn't wrap (automine toggle, mempool status, mine).
async function rpc(method: string, params: unknown[] = []): Promise<any> {
    const res = await fetch(config.rpcUrl, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
    });
    const j = await res.json();
    if (j.error) throw new Error(`${method}: ${JSON.stringify(j.error)}`);
    return j.result;
}

async function pendingCount(): Promise<number> {
    const status = await rpc("txpool_status");
    return parseInt(status.pending, 16);
}

async function main(): Promise<void> {
    const poolId = getPoolId(poolKey);
    const redis = new Redis(config.redisUrl);

    await rpc("evm_setAutomine", [false]);
    try {
        // Fresh round: drop any leftover orders/intents so a past-block order or an already-used intent
        // nonce can't poison this batch. Demo behavior — a production relay expires these by block/deadline.
        await redis.del(`orders:${poolId.toLowerCase()}`, `intents:${poolId.toLowerCase()}`);

        const head = await publicClient.getBlockNumber();
        const targetBlock = head + 1n;
        console.log(`automine off. head=${head} target=${targetBlock}`);

        await postBatch(targetBlock);

        console.log("waiting for operator settle + aggregator commit to queue (2 pending txs)...");
        const deadline = Date.now() + 30_000;
        for (;;) {
            const n = await pendingCount();
            if (n >= 2) break;
            if (Date.now() > deadline) {
                throw new Error(`timed out with ${n} pending tx(s); check the operator/aggregator logs`);
            }
            await sleep(500);
        }

        console.log(`mining block ${targetBlock} (commit + settle together)...`);
        await rpc("anvil_mine", ["0x1"]);

        const commitment = (await publicClient.readContract({
            address: config.taskManager,
            abi: taskManagerAbi,
            functionName: "getCommitment",
            args: [poolId, targetBlock],
        })) as { resultHash: string; executor: string; exists: boolean };
        console.log(`\ncommitment: exists=${commitment.exists} executor=${commitment.executor}`);
        console.log(`            resultHash=${commitment.resultHash}`);

        const block = await publicClient.getBlock({ blockNumber: targetBlock, includeTransactions: true });
        for (const tx of block.transactions) {
            const receipt = await publicClient.getTransactionReceipt({ hash: (tx as { hash: `0x${string}` }).hash });
            console.log(`  tx ${receipt.transactionHash} -> ${receipt.status}`);
        }

        // The economics of what just happened — the whole point, made visible: how much arb surplus was
        // captured for LPs, the reward distributed, and each user swap at the single uniform price.
        await reportRound(targetBlock);
    } finally {
        // Leave the batch cleared so the standalone operator sees empty blocks (and stays quiet) between
        // rounds, rather than re-settling the just-consumed intent and reverting with NonceUsed.
        await redis.del(`orders:${poolId.toLowerCase()}`, `intents:${poolId.toLowerCase()}`);
        await rpc("evm_setAutomine", [true]);
        await redis.quit();
        console.log("automine restored.");
    }
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
