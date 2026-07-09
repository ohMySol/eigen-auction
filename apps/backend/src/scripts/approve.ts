// One-time approvals so the Settler can pull tokens during settle. The winning searcher pays its
// order's quantityIn and each user pays its intent's amountIn via ERC20 transferFrom, which needs an
// allowance to the Settler. Run once after deploy/fund, with automine ON (these are normal txs). Idempotent.
//
// Run: make approve
import "dotenv/config";
import { createWalletClient, http, erc20Abi, maxUint256, type Address, type Hex } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { config, poolKey } from "@eigen-auction/shared/config";
import { SEARCHERS } from "./post-batch";

async function approve(pk: Hex, token: Address): Promise<void> {
    const wallet = createWalletClient({ account: privateKeyToAccount(pk), transport: http(config.rpcUrl) });
    await wallet.writeContract({
        address: token,
        abi: erc20Abi,
        functionName: "approve",
        args: [config.settler, maxUint256],
        chain: null,
    });
}

async function main(): Promise<void> {
    const userPk = (process.env.DEPLOYER_PK ?? "").trim() as Hex;
    // The user (intent payer) and every searcher (potential arb winner) approve both currencies.
    for (const pk of [userPk, ...SEARCHERS]) {
        await approve(pk, poolKey.currency0);
        await approve(pk, poolKey.currency1);
        console.log(`approved Settler for ${privateKeyToAccount(pk).address}`);
    }
    console.log(`\nSettler ${config.settler} approved for all searchers + the user.`);
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
