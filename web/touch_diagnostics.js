// Opt-in, local-only diagnostics. No telemetry is uploaded.
(() => {
  const url = new URL(location.href);
  const enabled = url.searchParams.get('touch_test') === '1';
  if (!enabled) return;
  const link = document.createElement('a');
  link.id = 'touch-test-link';
  const next = new URL(url);
  next.searchParams.delete('touch_test');
  link.href = next.href;
  link.textContent = 'Exit test';
  link.title = 'Return to the game menu';
  document.body.appendChild(link);

  const panel = document.createElement('section');
  panel.id = 'touch-diagnostics';
  panel.innerHTML = `<strong>TOUCH TEST</strong> <span id="touch-environment"></span>
    <button id="touch-report-button" type="button">Copy report</button>
    <div>Drag left thumb to move; up to climb the centre ladder. Tap right to jump; swipe right to dash.</div>
    <pre id="touch-readout">Waiting for the game engine…</pre>
    <div id="touch-checks">Walk: waiting · Climb: waiting · Jump: waiting · Dash: waiting</div>
    <details id="touch-report-details"><summary>Report / build details</summary>
      <div>No report is sent automatically. Copy this text back to the developer.</div>
      <textarea id="touch-report" readonly aria-label="Touch diagnostic report"></textarea>
    </details>`;
  document.body.appendChild(panel);
  const readout = document.getElementById('touch-readout');
  const reportBox = document.getElementById('touch-report');
  const raw = {touchstart:0, touchmove:0, touchend:0, touchcancel:0, mousemove:0};
  const checks = {Walk:false, Climb:false, Jump:false, Dash:false};
  const history = [], resets = [];
  let latest = null, lastRaw = null;
  const standalone = () => navigator.standalone === true || matchMedia('(display-mode: standalone)').matches;
  document.getElementById('touch-environment').textContent = (standalone() ? 'HOME SCREEN' : 'SAFARI / BROWSER') + ' · Build ' + (window.HOOSHANG_BUILD || 'unknown');
  const gameCanvas = document.getElementById('canvas');
  const now = () => Math.round(performance.now());
  for (const type of Object.keys(raw)) {
    gameCanvas.addEventListener(type, event => {
      raw[type]++;
      lastRaw = {type, time:now(), trusted:event.isTrusted,
        touches:Array.from(event.changedTouches || []).map(t => ({id:t.identifier, x:t.clientX, y:t.clientY}))};
    }, {capture:true, passive:true});
  }
  function report() {
    return JSON.stringify({build:window.HOOSHANG_BUILD || 'unknown', standalone:standalone(),
      userAgent:navigator.userAgent, pixelRatio:devicePixelRatio,
      // Only the asset path, never passwords or query parameters.
      asset:location.origin + location.pathname,
      viewport:{width:innerWidth,height:innerHeight,visualWidth:visualViewport?.width,visualHeight:visualViewport?.height},
      canvas:{width:gameCanvas.width,height:gameCanvas.height,rect:gameCanvas.getBoundingClientRect().toJSON()},
      raw,lastRaw,checks,latest,resets,history}, null, 2);
  }
  window.HooshangTouchTest = {
    reset(reason) { resets.push({time:now(),reason}); if (resets.length > 40) resets.shift(); },
    engine(json) {
      latest = JSON.parse(json);
      const v = latest.velocity || [0,0], m = latest.movement;
      for (const key of Object.keys(checks)) checks[key] ||= latest.checks[key];
      history.push({time:now(), raw:{...raw}, ...latest});
      if (history.length > 160) history.shift();
      readout.textContent = `Browser: ${raw.touchstart} presses / ${raw.touchmove} drags | Godot: ${latest.events.press} / ${latest.events.drag}\n` +
        `Thumb: ${m.map(n=>n.toFixed(2)).join(', ')} | fingers: ${latest.fingers.join(', ')} | ${latest.state || 'no player'}\n` +
        `Player speed: ${v.map(n=>n.toFixed(1)).join(', ')} | controls: ${latest.available ? 'ready' : 'blocked'} | reset: ${resets.at(-1)?.reason || 'none'}`;
      document.getElementById('touch-checks').textContent = Object.entries(checks).map(([key,ok])=>`${key}: ${ok ? 'PASS' : 'waiting'}`).join(' · ');
    },
    report,
  };
  document.getElementById('touch-report-details').addEventListener('toggle', () => { reportBox.value = report(); });
  document.getElementById('touch-report-button').addEventListener('click', async event => {
    reportBox.value = report();
    try {
      await navigator.clipboard.writeText(reportBox.value);
      event.target.textContent = 'Copied!';
    } catch (_) {
      document.getElementById('touch-report-details').open = true;
      reportBox.focus(); reportBox.select();
      event.target.textContent = 'Select & copy report below';
    }
  });
})();
