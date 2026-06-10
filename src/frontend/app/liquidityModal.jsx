/* ============================================================
   Liquidity management modal — Add / Remove
   ============================================================ */

import React from "react";
import { EA } from "./data.js";
import { Btn } from "./ui.jsx";
import { IS_LIVE } from "./chain/deployment.js";
import { useWallet, usePositionLiquidity, useAddLiquidity, useRemoveLiquidity } from "./chain/hooks.js";

function LiquidityModal({ open, mode, setMode, position, poolPrice, onClose, onApply }) {
  const [addEth, setAddEth] = React.useState('1.0');
  const [addUsdc, setAddUsdc] = React.useState('');
  const [lower, setLower] = React.useState(position.priceLower);
  const [upper, setUpper] = React.useState(position.priceUpper);
  const [pct, setPct] = React.useState(50);
  const [busy, setBusy] = React.useState(false);

  // Live add/remove through the hook when a deployment + wallet are present; else the mock animation.
  const { address } = useWallet();
  const { liquidity: posLiquidity } = usePositionLiquidity(address);
  const { addLiquidity } = useAddLiquidity();
  const { removeLiquidity } = useRemoveLiquidity();
  const live = IS_LIVE && !!address;

  React.useEffect(() => {
    if (open) {
      setLower(position.priceLower); setUpper(position.priceUpper);
      setAddEth('1.0'); setAddUsdc(''); setPct(50); setBusy(false);
    }
  }, [open]);

  // auto-balance USDC against ETH when user types ETH (and field empty / following)
  const ethN = Number(addEth || 0);
  const usdcN = addUsdc === '' ? +(ethN * poolPrice).toFixed(2) : Number(addUsdc || 0);
  const addValue = ethN * poolPrice + usdcN;

  const posValue = position.amountEth * poolPrice + position.amountUsdc;
  const outEth = position.amountEth * (pct / 100);
  const outUsdc = position.amountUsdc * (pct / 100);
  const outValue = outEth * poolPrice + outUsdc;

  if (!open) return null;

  function confirm() {
    if (live) {
      setBusy(true);
      (async () => {
        try {
          if (mode === 'add') {
            await addLiquidity(address, usdcN, ethN);
            onApply(position, 'Added liquidity · tx confirmed');
          } else {
            const liq = posLiquidity ? (posLiquidity * BigInt(Math.round(pct))) / 100n : 0n;
            if (liq <= 0n) throw new Error('nothing to remove');
            await removeLiquidity(liq);
            onApply(position, 'Removed ' + pct + '% · sent to wallet');
          }
          onClose();
        } catch {
          onApply(position, 'Transaction failed');
          setBusy(false);
        }
      })();
      return;
    }
    setBusy(true);
    setTimeout(() => {
      if (mode === 'add') {
        const ratio = (posValue + addValue) / (posValue || 1);
        onApply({
          ...position,
          amountEth: +(position.amountEth + ethN).toFixed(4),
          amountUsdc: +(position.amountUsdc + usdcN).toFixed(2),
          priceLower: Number(lower), priceUpper: Number(upper),
          liquidityNum: +(position.liquidityNum * ratio).toFixed(2),
          poolShareBps: Math.round(position.poolShareBps * ratio),
        }, 'Added ' + EA.fmtUsd(addValue) + ' of liquidity');
      } else {
        const keep = 1 - pct / 100;
        onApply({
          ...position,
          amountEth: +(position.amountEth * keep).toFixed(4),
          amountUsdc: +(position.amountUsdc * keep).toFixed(2),
          liquidityNum: +(position.liquidityNum * keep).toFixed(2),
          poolShareBps: Math.max(0, Math.round(position.poolShareBps * keep)),
        }, 'Removed ' + EA.fmtUsd(outValue) + ' · sent to wallet');
      }
      onClose();
    }, 1300);
  }

  return (
    <div className="modal-overlay" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="modal">
        <div className="modal-head">
          <div className="seg">
            <button className={mode === 'add' ? 'on' : ''} onClick={() => setMode('add')}>Add</button>
            <button className={mode === 'remove' ? 'on' : ''} onClick={() => setMode('remove')}>Remove</button>
          </div>
          <button className="x" onClick={onClose} aria-label="Close">✕</button>
        </div>

        <div className="modal-sub">
          {EA.POOL.pair} · {(EA.POOL.feeBps / 100).toFixed(2)}% &nbsp;·&nbsp; position value {EA.fmtUsd(posValue)}
        </div>

        {mode === 'add' ? (
          <>
            <FieldMini>Deposit amounts</FieldMini>
            <div className="liq-field">
              <input className="liq-input" value={addEth} inputMode="decimal"
                onChange={(e) => { setAddEth(e.target.value.replace(/[^0-9.]/g, '')); }} />
              <span className="liq-tok"><span className="ico eth">Ξ</span>ETH</span>
            </div>
            <div className="liq-field">
              <input className="liq-input" value={addUsdc} placeholder={EA.fmtNum(ethN * poolPrice, 2)} inputMode="decimal"
                onChange={(e) => { setAddUsdc(e.target.value.replace(/[^0-9.]/g, '')); }} />
              <span className="liq-tok"><span className="ico usdc">$</span>USDC</span>
            </div>
            <div className="liq-balance">≈ balanced at {EA.fmtUsd(poolPrice, 2)} / ETH</div>

            <FieldMini>Price range (USDC per ETH)</FieldMini>
            <div className="range-row">
              <div className="range-cell">
                <span>Min</span>
                <input value={lower} inputMode="decimal" onChange={(e) => setLower(e.target.value.replace(/[^0-9.]/g, ''))} />
              </div>
              <div className="range-cell">
                <span>Max</span>
                <input value={upper} inputMode="decimal" onChange={(e) => setUpper(e.target.value.replace(/[^0-9.]/g, ''))} />
              </div>
            </div>
            <div className={'range-flag ' + (poolPrice >= Number(lower) && poolPrice <= Number(upper) ? 'in' : 'out')}>
              {poolPrice >= Number(lower) && poolPrice <= Number(upper)
                ? '● In range — earns fees + LVR rebate now'
                : '○ Out of range — idle until price returns'}
            </div>

            <div className="liq-summary">
              <div className="kv"><span className="k">Adding</span><span className="v pos">{EA.fmtUsd(addValue)}</span></div>
              <div className="kv"><span className="k">New position value</span><span className="v">{EA.fmtUsd(posValue + addValue)}</span></div>
            </div>
          </>
        ) : (
          <>
            <FieldMini>Amount to remove</FieldMini>
            <div className="pct-big mono">{pct}%</div>
            <input type="range" min="1" max="100" value={pct} className="pct-slider"
              onChange={(e) => setPct(Number(e.target.value))} />
            <div className="pct-quick">
              {[25, 50, 75, 100].map((q) => (
                <button key={q} className={pct === q ? 'on' : ''} onClick={() => setPct(q)}>{q === 100 ? 'Max' : q + '%'}</button>
              ))}
            </div>
            <div className="liq-summary">
              <div className="kv"><span className="k"><span className="ico eth" style={{ width: 18, height: 18, marginRight: 8, display: 'inline-grid' }}>Ξ</span>ETH out</span><span className="v">{EA.fmtNum(outEth, 4)}</span></div>
              <div className="kv"><span className="k"><span className="ico usdc" style={{ width: 18, height: 18, marginRight: 8, display: 'inline-grid' }}>$</span>USDC out</span><span className="v">{EA.fmtNum(outUsdc, 2)}</span></div>
              <div className="divider" style={{ margin: '4px 0' }} />
              <div className="kv"><span className="k">Total to wallet</span><span className="v">{EA.fmtUsd(outValue)}</span></div>
            </div>
            <div className="hint" style={{ marginTop: 10 }}>Unclaimed LVR rewards are not withdrawn — claim them separately.</div>
          </>
        )}

        <Btn block onClick={confirm} disabled={busy || (mode === 'add' && addValue <= 0)} style={{ marginTop: 18 }}>
          {busy ? 'Confirming…' : mode === 'add' ? 'Add liquidity' : 'Remove liquidity'}
        </Btn>
      </div>
    </div>
  );
}

function FieldMini({ children }) {
  return <div style={{ fontSize: 11, letterSpacing: '.06em', textTransform: 'uppercase', color: 'var(--text-dim)', fontWeight: 600, margin: '18px 0 9px' }}>{children}</div>;
}

export { LiquidityModal };
