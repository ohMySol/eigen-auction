/* ============================================================
   View 1 — LP Dashboard
   ============================================================ */

import { formatUnits } from "viem";
import { EA } from "./data.js";
import { Icon, Card, Stat, Pill, Btn, TokenRow, AreaChart } from "./ui.jsx";
import { IS_LIVE } from "./chain/deployment.js";
import { useWallet, useEarned, useClaim, useFaucet } from "./chain/hooks.js";

function ConnectPrompt({ onConnect }) {
  return (
    <div className="card" style={{ textAlign: 'center', padding: '60px 30px', maxWidth: 460, margin: '40px auto' }}>
      <div style={{ width: 46, height: 46, borderRadius: 12, background: 'var(--surface-2)',
        border: '1px solid var(--line-2)', display: 'grid', placeItems: 'center', margin: '0 auto 18px', color: 'var(--text-mut)' }}>
        <Icon name="wallet" size={22} />
      </div>
      <h2 style={{ margin: '0 0 8px', fontSize: 19, fontWeight: 600 }}>Connect to view your position</h2>
      <p style={{ margin: '0 0 22px', color: 'var(--text-mut)', fontSize: 14 }}>
        EigenAuction reads your in-range liquidity and the LVR rebate accrued to it. Read-only — no signature needed to view.
      </p>
      <Btn onClick={onConnect}><Icon name="wallet" size={16} /> Connect wallet</Btn>
    </div>
  );
}

function DashboardView({ connected, onConnect, rewards, claiming, onClaim, position, onManage, onToast }) {
  // Hooks run unconditionally (before the early return) to satisfy the rules of hooks; they no-op
  // until a live deployment + connected account are present.
  const { address } = useWallet();
  const earned = useEarned(address);
  const { claim, isPending: claimingLive } = useClaim();
  const { faucet, isPending: faucetPending } = useFaucet();

  if (!connected) return <ConnectPrompt onConnect={onConnect} />;

  const live = IS_LIVE && connected;
  const P = position;
  // The demo pool is currency0 ~ mUSD / currency1 ~ mETH; live reward amounts come from hook.earned.
  const usdcRwd = live ? Number(formatUnits(earned.amount0 ?? 0n, earned.dec0)) : rewards.usdc;
  const ethRwd = live ? Number(formatUnits(earned.amount1 ?? 0n, earned.dec1)) : rewards.eth;
  const hasRewards = ethRwd > 1e-9 || usdcRwd > 1e-9;
  const claimingNow = live ? claimingLive : claiming;
  const doClaim = live
    ? async () => {
        try { await claim(); await earned.refetch(); onToast && onToast('Rewards claimed · tx confirmed'); }
        catch { onToast && onToast('Claim failed'); }
      }
    : onClaim;
  const doFaucet = async () => {
    try { await faucet(); onToast && onToast('Test tokens sent to your wallet'); }
    catch { onToast && onToast('Faucet failed'); }
  };
  const rewardUsd = ethRwd * EA.seed.poolPrice + usdcRwd;
  const inRange = EA.seed.poolPrice >= P.priceLower && EA.seed.poolPrice <= P.priceUpper;

  return (
    <>
      <div className="grid cols-2">
        {/* LEFT — position + history */}
        <div className="grid" style={{ alignContent: 'start' }}>
          <Card
            title="Your position"
            right={<div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <Pill kind={inRange ? 'acc' : 'amb'}>{inRange ? '● in range' : '○ out of range'}</Pill>
              <div style={{ display: 'flex', gap: 6 }}>
                {live && <button className="mini-btn" onClick={doFaucet} disabled={faucetPending}>{faucetPending ? '…' : 'Faucet'}</button>}
                <button className="mini-btn" onClick={() => onManage('add')}>+ Add</button>
                <button className="mini-btn" onClick={() => onManage('remove')}>− Remove</button>
              </div>
            </div>}
          >
            <div className="grid cols-3" style={{ gap: 14, marginBottom: 4 }}>
              <Stat sm label="Range (USDC / ETH)" value={EA.fmtNum(P.priceLower, 0)} sub={'→ ' + EA.fmtNum(P.priceUpper, 0)} />
              <Stat sm label="Liquidity (L)" value={P.liquidityNum + 'M'} sub={'pool share ' + (P.poolShareBps / 100).toFixed(2) + '%'} />
              <Stat sm label="Value" value={EA.fmtCompact(P.amountEth * EA.seed.poolPrice + P.amountUsdc)} sub="ETH + USDC" />
            </div>
            <div className="divider" />
            <TokenRow sym="ETH" full="Ether" ico="eth" amt={EA.fmtNum(P.amountEth, 4)} usd={EA.fmtUsd(P.amountEth * EA.seed.poolPrice)} />
            <TokenRow sym="USDC" full="USD Coin" ico="usdc" amt={EA.fmtNum(P.amountUsdc, 2)} usd={EA.fmtUsd(P.amountUsdc)} />
          </Card>

          <Card title="Rebate accrual" sub="Cumulative LVR rebate to this position · 30d" right={<Pill kind="acc">{EA.fmtCompact(EA.HISTORY[EA.HISTORY.length-1].cum)}</Pill>}>
            <AreaChart data={EA.HISTORY} />
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, color: 'var(--text-dim)',
              fontFamily: 'var(--font-mono)', marginTop: 6 }}>
              <span>30d ago</span><span>today</span>
            </div>
          </Card>
        </div>

        {/* RIGHT — claim */}
        <div className="grid" style={{ alignContent: 'start' }}>
          <Card
            title="Unclaimed rewards"
            sub="hook.earned(key, you, tickLower, tickUpper, salt)"
            style={{ borderColor: hasRewards ? 'color-mix(in oklab, var(--accent) 32%, var(--line))' : 'var(--line)' }}
          >
            <div className="stat" style={{ marginBottom: 14 }}>
              <div className="label">Total claimable</div>
              <div className="value pos" style={{ fontSize: 34 }}>{EA.fmtUsd(rewardUsd)}</div>
            </div>
            <TokenRow sym="ETH" full="Ether" ico="eth" amt={EA.fmtNum(ethRwd, 5)} usd={EA.fmtUsd(ethRwd * EA.seed.poolPrice)} />
            <TokenRow sym="USDC" full="USD Coin" ico="usdc" amt={EA.fmtNum(usdcRwd, 2)} usd={EA.fmtUsd(usdcRwd)} />
            <div style={{ marginTop: 18 }}>
              <Btn block disabled={!hasRewards || claimingNow} onClick={doClaim}>
                {claimingNow ? 'Confirming…' : hasRewards ? <><Icon name="down" size={16} /> Claim rewards</> : 'Nothing to claim'}
              </Btn>
            </div>
            <div className="hint" style={{ textAlign: 'center', marginTop: 10 }}>
              {claimingNow ? 'Submitting hook.claimRewards(key, …)' : 'Sent to your wallet · gas ≈ 0.0004 ETH'}
            </div>
          </Card>

          <Card title="Lifetime earned">
            <div className="kvs">
              <div className="kv"><span className="k">ETH claimed</span><span className="v pos">{EA.fmtNum(rewards.lifetimeEth, 4)} Ξ</span></div>
              <div className="kv"><span className="k">USDC claimed</span><span className="v pos">{EA.fmtNum(rewards.lifetimeUsdc, 2)}</span></div>
              <div className="kv"><span className="k">Claim count</span><span className="v">{rewards.claims}</span></div>
              <div className="divider" style={{ margin: '4px 0' }} />
              <div className="kv"><span className="k">vs. fees-only (est.)</span><span className="v pos">+34.2%</span></div>
            </div>
          </Card>
        </div>
      </div>
    </>
  );
}

export { DashboardView };
