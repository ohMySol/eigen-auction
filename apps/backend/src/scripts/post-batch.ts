// Searcher + user driver for the multi-operator BLS auction. Signs a set of competing searcher
// ToBOrders and a user SwapIntent for one target block and POSTs them to the relay (/order, /intent).
// The Go operator then pulls the sealed set via GET /auction/{block}, elects the winner, and the round
// proceeds. This is the "what a searcher/user does" script for the new flow (the old full-demo.ts uses
// the legacy EIP-191 /bid path).
//
// Prereqs: make deploy-fork done; docker compose up -d redis; make start-server (relay on :INTENT_PORT).
// Run:      npm run post-batch
// Then mine blocks (e.g. `cast rpc anvil_mine 0x1`) so the operator's head reaches the target block.
import "dotenv/config";
import { privateKeyToAccount } from "viem/accounts";
import { type Hex } from "viem";
import { config, poolKey, publicClient } from "@eigen-auction/shared/config";
import { getPoolId, signToBOrder, signIntent } from "@eigen-auction/shared";
import { clearingPriceX128 } from "../avs-rpc/seal";

// Three competing searchers (anvil accounts #2-#4). Each offers to pay the same currency0 but demands a
// different amount of currency1 out — the one leaving the most LP surplus wins under auction rule A.
export const SEARCHERS: Hex[] = [
    "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a",
    "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6",
    "0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a",
];
// Surplus each searcher leaves for LPs, in basis points of the fair output. Higher = more competitive.
const SURPLUS_BPS = [100n, 200n, 500n];

// Must match the operator's targetOffset so the order's validForBlock lands on the block the operator
// seals and the commit+settle mine into (operator processes target = head + 1).
const SETTLE_OFFSET = 1n;
const unit0 = 10n ** BigInt(config.decimals0);

async function post(path: string, body: unknown): Promise<void> {
    const res = await fetch(`http://127.0.0.1:${config.intentPort}${path}`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
    });
    if (!res.ok) throw new Error(`${path} -> ${res.status} ${await res.text()}`);
}

// Sign the competing searcher orders + a user intent for `targetBlock` and POST them to the relay.
// Exported so the drive-round orchestrator can reuse it.
export async function postBatch(targetBlock: bigint): Promise<void> {
    const poolId = getPoolId(poolKey);
    const price = clearingPriceX128(config.fixedPrice, config.decimals0, config.decimals1);

    // Fair currency1 output for the searcher's currency0 input, at the stamped clearing price.
    const quantityIn = 2000n * unit0;
    const fairOut = (quantityIn * price) >> 128n;

    console.log(`target block ${targetBlock}  clearingPriceX128 ${price}`);

    for (let i = 0; i < SEARCHERS.length; i++) {
        const acct = privateKeyToAccount(SEARCHERS[i]);
        const quantityOut = fairOut - (fairOut * SURPLUS_BPS[i]) / 10_000n;
        const order = {
            searcher: acct.address,
            poolId,
            zeroForOne: true,
            useInternal: false,
            quantityIn,
            quantityOut,
            validForBlock: targetBlock,
        };
        await post("/order", {
            ...order,
            quantityIn: quantityIn.toString(),
            quantityOut: quantityOut.toString(),
            validForBlock: targetBlock.toString(),
            signature: await signToBOrder(acct, config.settler, config.chainId, order),
        });
        console.log(`  order  ${acct.address}  out=${quantityOut}  surplus=${SURPLUS_BPS[i]}bps`);
    }

    // A user intent joins the same block's batch, filled at the uniform clearing price.
    const userPk = (process.env.DEPLOYER_PK ?? "").trim() as Hex;
    const user = privateKeyToAccount(userPk);
    const amountIn = 100n * unit0;
    const intent = {
        user: user.address,
        poolId,
        zeroForOne: true,
        useInternal: false,
        amountIn,
        minAmountOut: 0n,
        nonce: BigInt(Date.now()),
        deadline: BigInt(Math.floor(Date.now() / 1000) + 600),
    };
    await post("/intent", {
        ...intent,
        amountIn: amountIn.toString(),
        minAmountOut: "0",
        nonce: intent.nonce.toString(),
        deadline: intent.deadline.toString(),
        signature: await signIntent(user, config.settler, config.chainId, intent),
    });
    console.log(`  intent ${user.address}  amountIn=${amountIn}`);
    console.log(`  posted batch for block ${targetBlock}`);
}

async function main(): Promise<void> {
    const targetBlock = (await publicClient.getBlockNumber()) + SETTLE_OFFSET;
    await postBatch(targetBlock);
    console.log(`\nMine so the operator seals /auction/${targetBlock} — or use \`make drive-round\` to orchestrate the whole round.`);
}

// Only run standalone; drive-round imports postBatch without triggering this.
if (require.main === module) {
    main().catch((err) => {
        console.error(err);
        process.exit(1);
    });
}
