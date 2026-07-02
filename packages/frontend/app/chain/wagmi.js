// wagmi configuration. One network per build, chosen by VITE_CHAIN_ID and matching the deployment
// artifact. An injected connector (MetaMask / browser wallet) keeps the custom-designed connect
// button intact — no third-party modal. VITE_RPC_URL overrides the default public transport.
import { http, createConfig } from "wagmi";
import { mainnet, sepolia, anvil } from "wagmi/chains";
import { injected } from "wagmi/connectors";
import { CHAIN_ID } from "./deployment.js";

const CHAINS_BY_ID = { 1: mainnet, 31337: anvil, 11155111: sepolia };

export const activeChain = CHAINS_BY_ID[CHAIN_ID] ?? sepolia;

const rpcUrl = import.meta.env.VITE_RPC_URL;

export const wagmiConfig = createConfig({
  chains: [activeChain],
  connectors: [injected()],
  transports: { [activeChain.id]: http(rpcUrl) },
});
