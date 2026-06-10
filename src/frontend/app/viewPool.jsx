/* ============================================================
   View 2 — Pool Stats
   ============================================================ */

import { EA } from "./data.js";
import { Icon, Card, Stat, Pill, GapMeter } from "./ui.jsx";
import { IS_LIVE } from "./chain/deployment.js";
import { usePoolPrice } from "./chain/hooks.js";

function PoolView({ poolPrice, cexPrice, totalLvr, arbCount, events }) {
  const lpCut = (EA.POOL.lpShareBps / 100).toFixed(0);
  // Live spot price from the V4 StateView when a deployment is wired in; else the mock simulation.
  const { price: livePrice } = usePoolPrice();
  const pPrice = IS_LIVE && livePrice != null ? livePrice : poolPrice;
  return (
    <>
      <div className="grid cols-2" style={{ marginBottom: 'var(--gap)' }}>
        {/* price gap */}
        <Card title="Price vs. CEX" sub="Pool sqrtPrice vs reference mid — the gap an arber closes"
          right={<Pill>block #{EA.seed.block.toLocaleString()}</Pill>}>
          <GapMeter pool={pPrice} cex={cexPrice} />
          <div className="divider" />
          <div className="kvs">
            <div className="kv"><span className="k">Pool sqrtPriceX96 → price</span><span className="v">{EA.fmtUsd(pPrice)}</span></div>
            <div className="kv"><span className="k">Reference CEX mid</span><span className="v">{EA.fmtUsd(cexPrice)}</span></div>
            <div className="kv"><span className="k">Fee tier · tick spacing</span><span className="v">{(EA.POOL.feeBps/100).toFixed(2)}% · {EA.POOL.tickSpacing}</span></div>
          </div>
        </Card>

        {/* totals */}
        <div className="grid" style={{ alignContent: 'start' }}>
          <Card title="Total LVR captured" sub="Lifetime, returned to LPs by the auction">
            <div className="value pos mono" style={{ fontSize: 40, fontWeight: 500, letterSpacing: '-0.02em' }}>
              {EA.fmtUsd(totalLvr, 0)}
            </div>
            <div className="grid cols-3" style={{ gap: 14, marginTop: 18 }}>
              <Stat sm label="Arbs settled" value={arbCount.toLocaleString()} />
              <Stat sm label="To LPs" value={lpCut + '%'} sub="rest to protocol" />
              <Stat sm label="Avg / arb" value={EA.fmtUsd(totalLvr / arbCount, 0)} />
            </div>
          </Card>

          {/* the pitch */}
          <div className="card" style={{ background: 'linear-gradient(135deg, color-mix(in oklab, var(--accent) 12%, var(--surface)), var(--surface))',
            borderColor: 'color-mix(in oklab, var(--accent) 30%, var(--line))' }}>
            <div style={{ display: 'flex', gap: 14, alignItems: 'flex-start' }}>
              <div style={{ width: 34, height: 34, borderRadius: 9, background: 'var(--accent)', color: 'var(--accent-ink)',
                display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name="spark" size={18} /></div>
              <div>
                <div style={{ fontSize: 16, fontWeight: 600, lineHeight: 1.35 }}>
                  Without this hook, this value would have gone to MEV bots.
                </div>
                <div style={{ color: 'var(--text-mut)', fontSize: 13, marginTop: 6 }}>
                  Searchers bid for the first-arb slot each block; their winning bid <i>is</i> the LVR, skimmed and routed pro-rata to in-range LPs instead of leaking to the mempool.
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* events */}
      <Card flush title="Recent settlements" sub="ArbitrageSettled — auction winner & LVR skimmed each block"
        right={<span className="blockchip" style={{ marginRight: 'var(--pad)' }}><span className="live" /> streaming</span>}>
        <table className="tbl">
          <thead>
            <tr>
              <th>Auction winner</th>
              <th>LVR skimmed</th>
              <th className="r">≈ USD</th>
              <th className="r">Block</th>
              <th className="r">When</th>
              <th className="r"></th>
            </tr>
          </thead>
          <tbody>
            {events.map((e) => (
              <tr key={e.id} className={e.fresh ? 'fresh' : ''}>
                <td className="addr">{EA.shortAddr(e.winner)}</td>
                <td className="pos">{EA.fmtNum(e.lvr.amt, e.lvr.token === 'ETH' ? 4 : 2)} {e.lvr.token}</td>
                <td className="r muted">{EA.fmtUsd(e.usd, 2)}</td>
                <td className="r muted">#{e.block.toLocaleString()}</td>
                <td className="r muted">{EA.agoLabel(e.agoSec)}</td>
                <td className="r"><span style={{ color: 'var(--text-dim)' }}><Icon name="ext" size={14} /></span></td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </>
  );
}

export { PoolView };
