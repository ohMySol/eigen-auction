// Chain writes for the operator: commit the AVS winner, then settle the block.
// Reads live in pool-price.ts; this module holds the two state-changing transactions.
import { createWalletClient, http, erc20Abi, maxUint256, type Hex, type Address } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { config, poolKey, publicClient, requireOperatorKeys } from "../../shared/config";
import { auctionServiceManagerAbi, settlerAbi } from "../../shared/abi";
import type { SwapIntentT, SwapParamsT } from "../../shared/types";

// A wallet client bound to a private key. chain is null because we target a bare RPC (Anvil/fork)
// and pass an explicit chainId via the transport rather than a viem chain object.
function walletFor(pk: `0x${string}`) {
    return createWalletClient({ account: privateKeyToAccount(pk), transport: http(config.rpcUrl) });
}

// Commit the per-block auction winner to AuctionServiceManager with the operator quorum's
// signatures. Signed by the operator key. Waits for the receipt so the loop knows it landed.
export async function commitWinner(
    poolId: Hex,
    targetBlock: bigint,
    winner: Address,
    bidAmount: bigint,
    signatures: Hex[],
): Promise<Hex> {
    const { operatorPk } = requireOperatorKeys();
    const hash = await walletFor(operatorPk).writeContract({
        address: config.asm,
        abi: auctionServiceManagerAbi,
        functionName: "commitWinner",
        args: [poolId, targetBlock, winner, bidAmount, signatures],
        chain: null,
    });
    await publicClient.waitForTransactionReceipt({ hash });
    return hash;
}

// Settle the block as `callerPk`, which MUST equal the committed winner (the Settler enforces it).
// Step 1 arb rebalance (skipped if arb.amountSpecified == 0) then Step 2 intent fills, atomically.
export async function settleAs(
    callerPk: `0x${string}`,
    rewardAmount: bigint,
    arb: SwapParamsT,
    intents: SwapIntentT[],
): Promise<Hex> {
    const hash = await walletFor(callerPk).writeContract({
        address: config.settler,
        abi: settlerAbi,
        functionName: "settle",
        args: [poolKey, rewardAmount, arb, intents],
        chain: null,
    });
    await publicClient.waitForTransactionReceipt({ hash });
    return hash;
}

// Convenience: settle with the configured settler-caller key (the no-bid path, winner == operator).
export async function settle(rewardAmount: bigint, arb: SwapParamsT, intents: SwapIntentT[]): Promise<Hex> {
    const { settlerCallerPk } = requireOperatorKeys();
    return settleAs(settlerCallerPk, rewardAmount, arb, intents);
}

// One-time approval: Settler.settle does transferFrom(caller, hook, rewardAmount) for the LP
// reward, so the caller must have approved Settler to spend currency0. Call once on startup.
export async function ensureSettlerApproval(callerPk: `0x${string}`): Promise<void> {
    const caller = privateKeyToAccount(callerPk);
    const currency0 = poolKey.currency0 as Address;
    const allowance = await publicClient.readContract({
        address: currency0, abi: erc20Abi, functionName: "allowance",
        args: [caller.address, config.settler as Address],
    });
    if (allowance < maxUint256 / 2n) {
        console.log("approving Settler to spend currency0 for LP rewards…");
        const hash = await walletFor(callerPk).writeContract({
            address: currency0, abi: erc20Abi, functionName: "approve",
            args: [config.settler as Address, maxUint256], chain: null,
        });
        await publicClient.waitForTransactionReceipt({ hash });
        console.log("approval confirmed");
    }
}
