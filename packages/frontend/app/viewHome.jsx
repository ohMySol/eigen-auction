/* ============================================================
   View 0 — Home / landing (animated flow-field hero)
   ============================================================ */

import React from "react";
import { EA } from "./data.js";
import { EAFlow } from "./anim.js";
import { Icon, Btn } from "./ui.jsx";

function HomeView({ go, totalLvr, arbCount }) {
  const ref = React.useRef(null);
  React.useEffect(() => {
    if (ref.current) EAFlow.mount(ref.current);
    return () => { EAFlow.destroy(); };
  }, []);

  const steps = [
    ['01', 'Searchers bid for the slot', 'Each block, arbitrageurs bid for the exclusive right to trade first against the pool — the most valuable position in the queue.'],
    ['02', 'The bid is the LVR', 'The winning bid equals the loss-versus-rebalancing the pool would otherwise bleed to the open mempool. EigenAuction skims it on-chain.'],
    ['03', 'LPs are made whole', 'That value is routed pro-rata to the in-range LPs who bore the risk. Claim it anytime from your dashboard.'],
  ];

  return (
    <div className="home">
      <section className="hero">
        <canvas ref={ref} className="hero-bg" />
        <div className="hero-veil" />
        <div className="hero-inner">
          <div className="eyebrow"><span className="d" /> Uniswap v4 hook · LVR redistribution</div>
          <h1 className="hero-title">Give LPs back<br />what MEV takes.</h1>
          <p className="lead">
            EigenAuction auctions the <b>first-arbitrage slot</b> on a Uniswap v4 pool every block.
            The winning bid <i>is</i> the LVR — captured on-chain and returned to the liquidity
            providers who bore it, instead of leaking to searchers.
          </p>
          <div className="cta-row">
            <Btn onClick={() => go('dashboard')}><Icon name="layers" size={16} /> Open LP Dashboard</Btn>
            <Btn kind="ghost" onClick={() => go('trade')}><Icon name="arrow" size={16} /> Trade</Btn>
          </div>
          <div className="chip-row">
            <div className="hchip"><b>{(EA.POOL.lpShareBps / 100).toFixed(0)}%</b><span>of LVR → LPs</span></div>
            <div className="hchip"><b>{EA.fmtCompact(totalLvr)}</b><span>recaptured</span></div>
            <div className="hchip"><b>{arbCount.toLocaleString()}</b><span>arbs settled</span></div>
            <div className="hchip"><b>0.05%</b><span>pool fee</span></div>
          </div>
        </div>
        <button className="scroll-hint" onClick={() => document.querySelector('.how').scrollIntoView({ block: 'start' })}>
          How it works <Icon name="down" size={14} />
        </button>
      </section>

      <section className="how">
        <div className="how-head">
          <div className="card-title">Mechanism</div>
          <h2>One auction, three winners avoided.</h2>
          <p>Today LVR leaks to whoever lands the first transaction. EigenAuction turns that race into a sealed bid and pays the proceeds back.</p>
        </div>
        <div className="grid cols-3 steps">
          {steps.map(([n, t, d]) => (
            <div className="step" key={n}>
              <div className="step-n">{n}</div>
              <div className="step-t">{t}</div>
              <div className="step-d">{d}</div>
            </div>
          ))}
        </div>
        <div className="how-foot">
          <span>Non-custodial · permissionless · settles in the hook's <span className="mono">afterSwap</span></span>
          <span style={{ display: 'inline-flex', gap: 18, alignItems: 'center' }}>
            <a className="link-btn" href="Logo Options.html" style={{ textDecoration: 'none' }}>Logo options <Icon name="ext" size={13} /></a>
            <button className="link-btn" onClick={() => go('pool')}>See live pool activity <Icon name="arrow" size={14} /></button>
          </span>
        </div>
      </section>
    </div>
  );
}

export { HomeView };
