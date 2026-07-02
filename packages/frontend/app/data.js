/* ============================================================
   EigenAuction — mock data + live-ish helpers
   Exposes to window: EA (namespace) with formatters, seed data,
   and a tiny simulator for block / price / arb-event ticks.
   Exported as the `EA` namespace (formatters, seed data, and a tiny block/price/arb simulator).
   ============================================================ */

// ---------- formatters ----------
  const fmtUsd = (n, dp = 2) =>
    '$' + Number(n).toLocaleString('en-US', { minimumFractionDigits: dp, maximumFractionDigits: dp });
  const fmtNum = (n, dp = 4) =>
    Number(n).toLocaleString('en-US', { minimumFractionDigits: dp, maximumFractionDigits: dp });
  const fmtCompact = (n) =>
    '$' + Intl.NumberFormat('en-US', { notation: 'compact', maximumFractionDigits: 2 }).format(n);
  const shortAddr = (a) => a.slice(0, 6) + '…' + a.slice(-4);

  const randAddr = () => {
    const hex = '0123456789abcdef';
    let s = '0x';
    for (let i = 0; i < 40; i++) s += hex[(Math.random() * 16) | 0];
    return s;
  };

  // ---------- pool config ----------
  const POOL = {
    pair: 'ETH / USDC',
    base: 'ETH',
    quote: 'USDC',
    feeBps: 5,            // 0.05%
    tickSpacing: 10,
    hookAddr: '0xE16e1A0c7100Ab1d000000aucti0nH00k4d9c',
    poolId: '0x8f2a…c41b',
    lpShareBps: 9000,     // 90% of LVR to LPs
  };

  // ---------- live-ish state seed ----------
  const seed = {
    block: 21904118,
    poolPrice: 3418.62,   // ETH in USDC (from pool sqrtPrice)
    cexPrice: 3422.95,    // reference CEX mid
    totalLvrUsd: 1412884, // lifetime captured
    arbCount: 9241,
  };

  // LP position (the connected wallet)
  const POSITION = {
    salt: '0x00',
    priceLower: 3250.0,
    priceupper: 3610.0,   // displayed
    priceUpper: 3610.0,
    liquidity: '8.42M',
    amountEth: 5.812,
    amountUsdc: 12480.0,
    poolShareBps: 42,     // 0.42%
    inRange: true,
  };

  // unclaimed rewards (LVR rebate) — ticks up slowly
  const REWARDS = {
    eth: 0.03864,
    usdc: 118.42,
    lifetimeEth: 1.2041,
    lifetimeUsdc: 3910.8,
    claims: 14,
  };

  // recent ArbitrageSettled events
  function makeEvent(block, agoSec) {
    const inEth = Math.random() > 0.5;
    const sizeEth = +(0.04 + Math.random() * 0.34).toFixed(4);
    const sizeUsd = +(120 + Math.random() * 740).toFixed(2);
    return {
      id: block + '-' + ((Math.random() * 1e6) | 0),
      winner: randAddr(),
      lvr: inEth ? { token: 'ETH', amt: sizeEth } : { token: 'USDC', amt: sizeUsd },
      usd: inEth ? sizeEth * seed.poolPrice : sizeUsd,
      block,
      agoSec,
      fresh: false,
    };
  }
  const EVENTS = [];
  (function seedEvents() {
    let b = seed.block;
    let ago = 11;
    for (let i = 0; i < 9; i++) {
      EVENTS.push(makeEvent(b, ago));
      b -= 1 + ((Math.random() * 2) | 0);
      ago += 12 + ((Math.random() * 26) | 0);
    }
  })();

  // reward accrual history (last 30 days, cumulative USD)
  const HISTORY = (function () {
    const pts = [];
    let cum = 0;
    for (let d = 29; d >= 0; d--) {
      const daily = 4 + Math.random() * 26 + (29 - d) * 0.5;
      cum += daily;
      pts.push({ day: d, daily: +daily.toFixed(2), cum: +cum.toFixed(2) });
    }
    return pts;
  })();

  function agoLabel(s) {
    if (s < 60) return s + 's ago';
    if (s < 3600) return Math.floor(s / 60) + 'm ago';
    return Math.floor(s / 3600) + 'h ago';
  }

export const EA = {
  fmtUsd, fmtNum, fmtCompact, shortAddr, randAddr, agoLabel,
  POOL, seed, POSITION, REWARDS, EVENTS, HISTORY, makeEvent,
};
