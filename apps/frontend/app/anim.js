/* ============================================================
   EigenAuction — "block fill" background animation
   A chain of blocks is produced in reading order; each block
   fills bottom-up with mint = the LVR captured that block.
   Slow + calm. Reads theme colors from CSS vars.
   Exported as `EAFlow.mount(canvas)` / `EAFlow.destroy()`.
   ============================================================ */

let raf = null, ro = null, canvas = null, ctx = null;
  let W = 0, H = 0, DPR = 1, lastT = 0, frame = 0;
  let bgRGB = '12,14,18', accent = [47, 224, 168], accent2 = [106, 160, 255], lineRGB = '46,52,63';

  let cells = [], cols = 0, rows = 0, cw = 0, ch = 0;
  const GAP = 14;
  let head = -1, phase = 'fill', acc = 0, stamp = 0;
  const STEP = 520;          // ms between new blocks (deliberate)
  const HOLD = 1700;         // ms to admire the full chain
  const DRAIN = 1500;        // ms to clear before restarting

  function hexToRgb(hex) {
    const c = (hex || '').trim().replace('#', '');
    if (c.length < 6) return null;
    return [parseInt(c.slice(0, 2), 16), parseInt(c.slice(2, 4), 16), parseInt(c.slice(4, 6), 16)];
  }
  function readTheme() {
    const cs = getComputedStyle(document.documentElement);
    const bg = hexToRgb(cs.getPropertyValue('--bg')); if (bg) bgRGB = bg.join(',');
    const ln = hexToRgb(cs.getPropertyValue('--line-2')); if (ln) lineRGB = ln.join(',');
    const a = hexToRgb(cs.getPropertyValue('--accent')); if (a) accent = a;
    const b = hexToRgb(cs.getPropertyValue('--blue')); if (b) accent2 = b;
  }

  function layout(prefill) {
    const target = Math.max(70, Math.min(110, Math.round(Math.sqrt((W * H) / 110)))); // adaptive
    cols = Math.max(4, Math.round(W / target));
    rows = Math.max(3, Math.round(H / target));
    cw = W / cols; ch = H / rows;
    cells = [];
    for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
      cells.push({ c, r, level: 0, target: 0.32 + Math.random() * 0.66, bright: 0, hue: Math.random() < 0.22 ? 1 : 0 });
    }
    phase = 'fill'; acc = 0; stamp = 0;
    head = prefill ? Math.floor(cells.length * (0.25 + Math.random() * 0.2)) : -1;
    if (prefill) for (let i = 0; i <= head; i++) cells[i].level = cells[i].target; // start partially built
  }

  function resize() {
    DPR = Math.min(window.devicePixelRatio || 1, 2);
    const r = canvas.getBoundingClientRect();
    W = Math.max(1, r.width); H = Math.max(1, r.height);
    canvas.width = W * DPR; canvas.height = H * DPR;
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    layout(true);
  }

  function roundRectPath(x, y, w, h, rad) {
    const r = Math.min(rad, w / 2, h / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  function update(dt) {
    frame++;
    if (frame % 50 === 0) readTheme();

    if (phase === 'fill') {
      acc += dt;
      while (acc >= STEP && head < cells.length - 1) { acc -= STEP; head++; cells[head].bright = 1; }
      if (head >= cells.length - 1) { phase = 'hold'; stamp = 0; }
    } else if (phase === 'hold') {
      stamp += dt; if (stamp >= HOLD) { phase = 'drain'; stamp = 0; }
    } else if (phase === 'drain') {
      stamp += dt; if (stamp >= DRAIN) layout(false);
    }

    const k = 1 - Math.pow(0.0009, dt / 1000);      // level smoothing (~tau 230ms)
    const kb = 1 - Math.pow(0.0009, dt / 1000);
    for (let i = 0; i < cells.length; i++) {
      const cell = cells[i];
      const goal = phase === 'drain' ? 0 : (i <= head ? cell.target : 0);
      cell.level += (goal - cell.level) * k;
      cell.bright += (0 - cell.bright) * kb * 0.7;
    }
  }

  function draw() {
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    ctx.fillStyle = 'rgb(' + bgRGB + ')';
    ctx.fillRect(0, 0, W, H);

    for (const cell of cells) {
      const x = cell.c * cw + GAP / 2, y = cell.r * ch + GAP / 2;
      const w = cw - GAP, h = ch - GAP;
      const col = cell.hue ? accent2 : accent;

      // block outline
      roundRectPath(x, y, w, h, 7);
      ctx.strokeStyle = 'rgba(' + lineRGB + ',' + (0.35 + cell.level * 0.35).toFixed(3) + ')';
      ctx.lineWidth = 1;
      ctx.stroke();

      if (cell.level > 0.012) {
        const fh = h * cell.level;
        ctx.save();
        roundRectPath(x, y, w, h, 7);
        ctx.clip();
        // fill body
        ctx.fillStyle = 'rgba(' + col.join(',') + ',' + (0.09 + cell.bright * 0.20).toFixed(3) + ')';
        ctx.fillRect(x, y + h - fh, w, fh);
        // filling surface line
        ctx.fillStyle = 'rgba(' + col.join(',') + ',' + (0.22 + cell.bright * 0.55).toFixed(3) + ')';
        ctx.fillRect(x, y + h - fh, w, 2);
        ctx.restore();
      }
    }
  }

  function step(now) {
    const dt = Math.min(64, now - lastT); lastT = now;
    update(dt); draw();
    raf = requestAnimationFrame(step);
  }

  function mount(el) {
    destroy();
    canvas = el; ctx = canvas.getContext('2d');
    readTheme(); resize();
    ro = new ResizeObserver(resize); ro.observe(canvas);
    lastT = performance.now();
    if (!window.matchMedia || !window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      raf = requestAnimationFrame(step);
    } else {
      // static: show a fully built chain
      for (const cell of cells) cell.level = cell.target;
      draw();
    }
  }
  function destroy() {
    if (raf) cancelAnimationFrame(raf), raf = null;
    if (ro && canvas) ro.unobserve(canvas);
    ro = null;
  }

export const EAFlow = { mount, destroy };
