// Round results reporter — surfaces the ECONOMICS of a settled block so a reader can see the benefit:
// the arbitrage surplus that would otherwise leak to searchers/builders is instead captured and paid to
// the LPs who hold the liquidity. Reads the round's on-chain events for one block:
//   ArbFilled        -> the currency0 surplus (bid) the arb left for LPs
//   ArbitrageSettled -> the reward actually distributed to in-range LPs
//   IntentFilled     -> each user swap, all cleared at one uniform price
//   BlockSettled     -> which operator (executor) settled the round
//
// Run: `make results` (latest settled block) or `make results BLOCK=<n>`. Also printed automatically at
// the end of `make drive-round`.
import "dotenv/config";
import { formatUnits, parseEventLogs, erc20Abi, type Address } from "viem";
import { config, poolKey, publicClient } from "@eigen-auction/shared/config";
import { getPoolId, auctionEventsAbi } from "@eigen-auction/shared";

// Best-effort token symbol; falls back to a short address so the report never fails on a missing symbol().
async function symbol(addr: Address): Promise<string> {
    try {
        return (await publicClient.readContract({ address: addr, abi: erc20Abi, functionName: "symbol" })) as string;
    } catch {
        return `${addr.slice(0, 6)}…`;
    }
}

// The auction events all come from the Settler (ArbFilled/IntentFilled/BlockSettled) or the hook
// (ArbitrageSettled), so every getLogs is scoped to those two addresses — smaller responses, and it
// avoids pulling unrelated mainnet-fork logs.
const eventAddresses = [config.settler, config.hook] as Address[];

// Scan backward for the newest settled round when no explicit block is given. A forked anvil proxies
// historical getLogs to the upstream RPC, which (on free tiers) caps the range at 10 blocks — so scan in
// 10-block chunks, and cap total lookback since demo rounds sit within a few blocks of head.
async function latestSettledBlock(poolId: string): Promise<bigint | undefined> {
    const head = await publicClient.getBlockNumber();
    const CHUNK = 10n;
    const floor = head > 200n ? head - 200n : 0n;
    for (let hi = head; ; hi -= CHUNK) {
        const lo = hi >= floor + CHUNK ? hi - CHUNK + 1n : floor;
        const logs = await publicClient.getLogs({ address: eventAddresses, fromBlock: lo, toBlock: hi });
        const settled = parseEventLogs({ abi: auctionEventsAbi, logs, eventName: "BlockSettled" })
            .filter((e) => e.args.poolId.toLowerCase() === poolId);
        if (settled.length) return settled[settled.length - 1].blockNumber;
        if (lo === floor) return undefined;
    }
}

// Parse + print the round at `targetBlock`. Exported so drive-round can call it directly after mining.
export async function reportRound(targetBlock: bigint): Promise<void> {
    const poolId = getPoolId(poolKey).toLowerCase();
    const logs = await publicClient.getLogs({ address: eventAddresses, fromBlock: targetBlock, toBlock: targetBlock });
    // Parse per event name so each array is precisely typed (a single parse returns an un-narrowed union).
    const mine = <T extends { args: { poolId: `0x${string}` } }>(arr: T[]) =>
        arr.filter((e) => e.args.poolId.toLowerCase() === poolId);
    const settled = mine(parseEventLogs({ abi: auctionEventsAbi, logs, eventName: "BlockSettled" }))[0];
    if (!settled) {
        console.log(`\nNo settled EigenAuction round found at block ${targetBlock} for this pool.`);
        return;
    }
    const arb = mine(parseEventLogs({ abi: auctionEventsAbi, logs, eventName: "ArbFilled" }))[0];
    const dist = mine(parseEventLogs({ abi: auctionEventsAbi, logs, eventName: "ArbitrageSettled" }))[0];
    const intents = mine(parseEventLogs({ abi: auctionEventsAbi, logs, eventName: "IntentFilled" }));

    const [sym0, sym1] = await Promise.all([symbol(poolKey.currency0 as Address), symbol(poolKey.currency1 as Address)]);
    const fmt0 = (v: bigint) => `${formatUnits(v, config.decimals0)} ${sym0}`;
    const bid = (arb?.args.bid as bigint) ?? 0n;
    const reward = (dist?.args.rewardAmount as bigint) ?? 0n;

    const line = "━".repeat(64);
    console.log(`\n${line}`);
    console.log(` EigenAuction — round results · block ${targetBlock}`);
    console.log(line);
    console.log(` Executor (operator that settled):  ${settled.args.operator}`);
    if (arb) console.log(` Winning arbitrageur:               ${arb.args.arber}`);
    console.log("");
    console.log(` LVR captured for LPs:              ${fmt0(bid)}`);
    console.log("   └ arbitrage surplus that WITHOUT this auction leaks to searchers /");
    console.log("     block builders. Here it is paid back to the LPs who carry the risk.");
    console.log(` Distributed to in-range LPs:       ${fmt0(reward)}`);
    console.log("");
    console.log(` User swaps filled (one uniform price):  ${intents.length}`);
    for (const it of intents) {
        const z = it.args.zeroForOne as boolean;
        const inSym = z ? sym0 : sym1, outSym = z ? sym1 : sym0;
        const inDec = z ? config.decimals0 : config.decimals1, outDec = z ? config.decimals1 : config.decimals0;
        const amtIn = formatUnits(it.args.amountIn as bigint, inDec);
        const amtOut = formatUnits(it.args.amountOut as bigint, outDec);
        console.log(`   ${it.args.user}  ${amtIn} ${inSym} → ${amtOut} ${outSym}`);
    }
    console.log(line);
    if (bid === 0n) console.log(" (No arb surplus this round — no competing top-of-block order left value on the table.)");
}

async function main(): Promise<void> {
    const poolId = getPoolId(poolKey).toLowerCase();
    const arg = (process.env.BLOCK ?? process.argv[2] ?? "").trim(); // env empty-string guard for `make results`
    const targetBlock = arg ? BigInt(arg) : await latestSettledBlock(poolId);
    if (targetBlock === undefined) {
        console.log("No settled EigenAuction round found in the last 200 blocks. Run `make drive-round` first.");
        return;
    }
    await reportRound(targetBlock);
}

if (require.main === module) {
    main().catch((err) => {
        console.error(err);
        process.exit(1);
    });
}
