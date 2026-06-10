/* ============================================================
   EigenAuction — shared UI primitives + small charts
   Exports: Card, Stat, TokenRow, Pill, Btn, AreaChart, GapMeter, Icon
   ============================================================ */

import { EA } from "./data.js";

function Icon({ name, size = 16, stroke = 1.8 }) {
  const p = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none',
    stroke: 'currentColor', strokeWidth: stroke, strokeLinecap: 'round', strokeLinejoin: 'round' };
  const paths = {
    wallet: <><rect x="3" y="6" width="18" height="13" rx="2"/><path d="M16 12h2"/><path d="M3 9h13a2 2 0 0 1 2 2"/></>,
    layers: <><path d="M12 3 3 8l9 5 9-5-9-5Z"/><path d="m3 13 9 5 9-5"/></>,
    activity: <path d="M3 12h4l3 8 4-16 3 8h4"/>,
    send: <><path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/></>,
    arrow: <><path d="M5 12h14"/><path d="m13 6 6 6-6 6"/></>,
    down: <><path d="M12 5v14"/><path d="m6 13 6 6 6-6"/></>,
    check: <path d="M20 6 9 17l-5-5"/>,
    spark: <path d="M13 2 4.5 13.5H11l-1 8.5L19.5 10H13l0-8Z"/>,
    ext: <><path d="M15 3h6v6"/><path d="M10 14 21 3"/><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/></>,
    lock: <><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></>,
    clock: <><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></>,
  };
  return <svg {...p}>{paths[name]}</svg>;
}

function Card({ title, sub, right, flush, children, style }) {
  return (
    <div className={'card' + (flush ? ' flush' : '')} style={style}>
      {(title || right) && (
        <div className={'card-head' + (flush ? ' pad' : '')}>
          <div>
            {title && <div className="card-title">{title}</div>}
            {sub && <div className="card-sub" style={{ marginTop: 4 }}>{sub}</div>}
          </div>
          {right}
        </div>
      )}
      {children}
    </div>
  );
}

function Stat({ label, value, unit, sub, subClass, sm }) {
  return (
    <div className="stat">
      <div className="label">{label}</div>
      <div className={'value' + (sm ? ' sm' : '')}>
        {value}{unit && <span className="unit">{unit}</span>}
      </div>
      {sub && <div className={'sub ' + (subClass || '')}>{sub}</div>}
    </div>
  );
}

function Pill({ kind, children }) {
  return <span className={'pill' + (kind ? ' ' + kind : '')}>{children}</span>;
}

function Btn({ kind = 'primary', block, children, ...rest }) {
  return (
    <button className={'btn btn-' + kind + (block ? ' btn-block' : '')} {...rest}>
      {children}
    </button>
  );
}

function TokenRow({ sym, full, ico, amt, usd }) {
  return (
    <div className="tokrow">
      <div className="tok">
        <span className={'ico ' + ico}>{sym === 'USDC' ? '$' : 'Ξ'}</span>
        <div>
          <div className="sym">{sym}</div>
          <div className="full">{full}</div>
        </div>
      </div>
      <div className="amt">
        {amt}
        {usd != null && <small>{usd}</small>}
      </div>
    </div>
  );
}

/* ---------- cumulative area chart (rewards history) ---------- */
function AreaChart({ data, height = 150, accessor = (d) => d.cum }) {
  const w = 560, h = height, pad = 6;
  const vals = data.map(accessor);
  const max = Math.max(...vals), min = Math.min(...vals, 0);
  const X = (i) => pad + (i / (data.length - 1)) * (w - pad * 2);
  const Y = (v) => h - pad - ((v - min) / (max - min || 1)) * (h - pad * 2 - 14);
  const line = data.map((d, i) => `${X(i)},${Y(accessor(d))}`).join(' ');
  const area = `${X(0)},${h - pad} ${line} ${X(data.length - 1)},${h - pad}`;
  const lastX = X(data.length - 1), lastY = Y(accessor(data[data.length - 1]));
  return (
    <svg viewBox={`0 0 ${w} ${h}`} width="100%" height={h} preserveAspectRatio="none" style={{ display: 'block' }}>
      <defs>
        <linearGradient id="eaFill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="var(--accent)" stopOpacity="0.28" />
          <stop offset="100%" stopColor="var(--accent)" stopOpacity="0" />
        </linearGradient>
      </defs>
      <polygon points={area} fill="url(#eaFill)" />
      <polyline points={line} fill="none" stroke="var(--accent)" strokeWidth="2"
        vectorEffect="non-scaling-stroke" strokeLinejoin="round" />
      <circle cx={lastX} cy={lastY} r="3.5" fill="var(--accent)" />
      <circle cx={lastX} cy={lastY} r="7" fill="var(--accent)" opacity="0.18" />
    </svg>
  );
}

/* ---------- the LVR gap meter (pool price vs CEX) ---------- */
function GapMeter({ pool, cex }) {
  const gap = cex - pool;
  const gapBps = (gap / pool) * 10000;
  const lo = Math.min(pool, cex), hi = Math.max(pool, cex);
  const span = (hi - lo) || 1;
  const total = span * 6;            // give the bar some breathing room
  const mid = (pool + cex) / 2;
  const left = ((pool - (mid - total / 2)) / total) * 100;
  const right = ((cex - (mid - total / 2)) / total) * 100;
  return (
    <div>
      <div style={{ position: 'relative', height: 64, margin: '20px 4px 8px' }}>
        <div style={{ position: 'absolute', top: 30, left: 0, right: 0, height: 3,
          background: 'var(--line-2)', borderRadius: 3 }} />
        {/* gap fill */}
        <div style={{ position: 'absolute', top: 30, left: left + '%', width: (right - left) + '%',
          height: 3, background: 'var(--amber)', borderRadius: 3 }} />
        {/* pool marker */}
        <Marker pct={left} color="var(--blue)" label="POOL" value={EA.fmtUsd(pool)} up />
        {/* cex marker */}
        <Marker pct={right} color="var(--text)" label="CEX MID" value={EA.fmtUsd(cex)} />
      </div>
      <div style={{ display: 'flex', justifyContent: 'center', marginTop: 14 }}>
        <Pill kind="amb">arb gap&nbsp; {EA.fmtUsd(Math.abs(gap))} &nbsp;·&nbsp; {Math.abs(gapBps).toFixed(1)} bps</Pill>
      </div>
    </div>
  );
}
function Marker({ pct, color, label, value, up }) {
  return (
    <div style={{ position: 'absolute', left: pct + '%', top: 0, transform: 'translateX(-50%)',
      display: 'flex', flexDirection: up ? 'column-reverse' : 'column', alignItems: 'center',
      height: '100%', justifyContent: 'space-between' }}>
      <div style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--text)' }}>{value}</div>
      <div style={{ width: 2, height: 14, background: color }} />
      <div style={{ width: 11, height: 11, borderRadius: '50%', background: color,
        border: '2px solid var(--surface)', position: 'absolute', top: up ? 'auto' : 25, bottom: up ? 25 : 'auto' }} />
      <div style={{ fontSize: 10, letterSpacing: '.08em', color: 'var(--text-dim)', fontWeight: 600 }}>{label}</div>
    </div>
  );
}

export { Icon, Card, Stat, Pill, Btn, TokenRow, AreaChart, GapMeter };
