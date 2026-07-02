// EigenAuction frontend entry point. Replaces the old in-browser Babel setup: Vite compiles the JSX
// ahead of time and this module mounts the app, wrapped in the wagmi + react-query providers that the
// chain hooks depend on.
import React from "react";
import ReactDOM from "react-dom/client";
import { WagmiProvider } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { wagmiConfig } from "./chain/wagmi.js";
import { App } from "./app.jsx";
import "./base.css";

const queryClient = new QueryClient();

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <App />
      </QueryClientProvider>
    </WagmiProvider>
  </React.StrictMode>
);
