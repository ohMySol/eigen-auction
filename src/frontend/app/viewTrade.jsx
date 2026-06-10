/* ============================================================
   View 3 — Trade (minimal swap UI over the auction)
   ============================================================ */

import React from "react";
import { parseUnits } from "viem";
import { EA } from "./data.js";
import { Icon, Btn } from "./ui.jsx";
import { useWallet, useSubmitIntent, DEC0, DEC1 } from "./chain/hooks.js";
import { IS_LIVE } from "./chain/deployment.js";

function TradeView({ connected, onConnect, poolPrice, onToast }) {
  const { address } = useWallet();
  const { submitIntent } = useSubmitIntent();

  const [dir, setDir] = React.useState('buy');        // buy = currency0→currency1
  const [pay, setPay] = React.useState('2500');
  const [slip, setSlip] = React.useState(0.5);
  const [phase, setPhase] = React.useState('idle');   // idle|signing|filling|done
  const [adv, setAdv] = React.useState(false);

  const inTok = dir === 'buy' ? 'USDC' : 'ETH';
  const outTok = dir === 'buy' ? 'ETH' : 'USDC';
  const payNum = Number(pay || 0);
  const rawOut = dir === 'buy' ? payNum / poolPrice : payNum * poolPrice;
  const out = rawOut * 0.9997;                          // 0.03% fee-ish
  const minOut = out * (1 - slip / 100);
  const outDp = outTok === 'ETH' ? 5 : 2;

  function flip() { setDir((d) => (d === 'buy' ? 'sell' : 'buy')); setPhase('idle'); }

  async function swap() {
    if (!connected) { onConnect(); return; }
    if (!payNum) return;

    if (IS_LIVE) {
      setPhase('signing');
      try {
        const inDec = dir === 'buy' ? DEC0 : DEC1;
        const outDec = dir === 'buy' ? DEC1 : DEC0;
        const amountIn = parseUnits(pay, inDec);
        const minAmountOut = parseUnits(minOut.toFixed(outDec), outDec);
        await submitIntent({
          account: address,
          zeroForOne: dir === 'buy',
          amountIn,
          minAmountOut,
          onSigned: () => setPhase('filling'),
        });
        setPhase('done');
        onToast?.('Intent submitted · filling at next block');
        setTimeout(() => setPhase('idle'), 2000);
      } catch (err) {
        setPhase('idle');
        onToast?.('Error: ' + (err.shortMessage ?? err.message ?? 'Unknown error'));
      }
      return;
    }

    // mock flow when no deployment is wired in
    setPhase('signing');
    setTimeout(() => {
      setPhase('filling');
      setTimeout(() => {
        setPhase('done');
        onToast?.('Swapped ' + EA.fmtNum(payNum, inTok === 'ETH' ? 4 : 2) + ' ' + inTok + ' → ' + EA.fmtNum(out, outDp) + ' ' + outTok);
        setTimeout(() => setPhase('idle'), 1400);
      }, 1000);
    }, 1000);
  }

  const busy = phase === 'signing' || phase === 'filling';

  return (
    <div className="trade-wrap">
      <div className="swap">
        <div className="swap-top">
          <span className="card-title">Swap</span>
          <span className="protected"><Icon name="lock" size={13} /> first-arb protected</span>
        </div>

        {/* pay */}
        <div className="swap-field">
          <div className="sf-head"><span>You pay</span><span className="muted">balance — </span></div>
          <div className="sf-row">
            <input className="sf-input" value={pay} inputMode="decimal"
              onChange={(e) => { setPay(e.target.value.replace(/[^0-9.]/g, '')); setPhase('idle'); }} />
            <div className="tokbtn"><span className={'ico ' + (inTok === 'ETH' ? 'eth' : 'usdc')}>{inTok === 'ETH' ? 'Ξ' : '$'}</span>{inTok}</div>
          </div>
          <div className="sf-sub">{EA.fmtUsd(dir === 'buy' ? payNum : payNum * poolPrice)}</div>
        </div>

        <button className="swap-flip" onClick={flip} aria-label="Flip direction"><Icon name="down" size={16} /></button>

        {/* receive */}
        <div className="swap-field">
          <div className="sf-head"><span>You receive</span><span className="muted">estimated</span></div>
          <div className="sf-row">
            <div className="sf-input out">{EA.fmtNum(out, outDp)}</div>
            <div className="tokbtn"><span className={'ico ' + (outTok === 'ETH' ? 'eth' : 'usdc')}>{outTok === 'ETH' ? 'Ξ' : '$'}</span>{outTok}</div>
          </div>
          <div className="sf-sub">{EA.fmtUsd(dir === 'buy' ? out * poolPrice : out)}</div>
        </div>

        {/* rate */}
        <div className="swap-rate">
          <span className="mono">1 ETH = {EA.fmtNum(poolPrice, 2)} USDC</span>
          <button className="link-btn" style={{ fontSize: 12 }} onClick={() => setAdv((v) => !v)}>
            {adv ? 'Hide details' : 'Details'}
          </button>
        </div>

        {adv && (
          <div className="swap-details">
            <div className="kv"><span className="k">Route</span><span className="v">EigenAuction · first-arb</span></div>
            <div className="kv"><span className="k">Min received</span><span className="v">{EA.fmtNum(minOut, outDp)} {outTok}</span></div>
            <div className="kv"><span className="k">Price impact</span><span className="v pos">0.01%</span></div>
            <div className="kv"><span className="k">Slippage</span>
              <span className="slips">
                {[0.1, 0.5, 1.0].map((s) => (
                  <button key={s} className={slip === s ? 'on' : ''} onClick={() => setSlip(s)}>{s}%</button>
                ))}
              </span>
            </div>
            <div className="kv"><span className="k">Signed as</span><span className="v muted">EIP-712 SwapIntent</span></div>
          </div>
        )}

        <Btn block onClick={swap} disabled={busy || (connected && !payNum)} style={{ marginTop: 16 }}>
          {phase === 'signing' ? 'Sign in wallet…' :
           phase === 'filling' ? 'Filling at next block…' :
           phase === 'done' ? <><Icon name="check" size={16} /> Swapped</> :
           !connected ? <><Icon name="wallet" size={16} /> Connect wallet</> :
           !payNum ? 'Enter an amount' :
           <><Icon name="arrow" size={16} /> Swap {inTok} → {outTok}</>}
        </Btn>

        <div className="swap-note">
          Your order is auctioned, not front-run. Searchers compete to fill it — the LVR they'd skim is captured for LPs.
        </div>
      </div>
    </div>
  );
}

export { TradeView };
