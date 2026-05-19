#!/usr/bin/env node
// Capture a PNG screenshot of a Lamdera tab via Chrome DevTools Protocol.
//
// Prereqs: same as cdp-console.js (debuggable Chrome on :9222, `npm install`).
//
// Usage:
//   node scripts/cdp-screenshot.js                       # → /tmp/lamdera-screenshot.png
//   node scripts/cdp-screenshot.js --out shot.png        # custom output path
//   node scripts/cdp-screenshot.js --full-page           # capture beyond viewport
//   node scripts/cdp-screenshot.js --any                 # don't insist on leader tab
//
// Prints the absolute output path on stdout; the Read tool can open the PNG.

const http = require('http');
const path = require('path');
const fs = require('fs');
const WebSocket = require('ws');

const args = process.argv.slice(2);
const anyTab = args.includes('--any');
const fullPage = args.includes('--full-page');
const outIdx = args.indexOf('--out');
const outPath = path.resolve(outIdx >= 0 ? args[outIdx + 1] : '/tmp/lamdera-screenshot.png');

const fetchTabs = () => new Promise((resolve, reject) => {
  http.get('http://localhost:9222/json', (res) => {
    let body = '';
    res.on('data', (c) => body += c);
    res.on('end', () => { try { resolve(JSON.parse(body)); } catch (e) { reject(e); } });
  }).on('error', reject);
});

function isLeaderTab(wsUrl) {
  return new Promise((resolve) => {
    const probe = new WebSocket(wsUrl);
    const timeout = setTimeout(() => { try { probe.close(); } catch {} resolve(false); }, 2000);
    probe.on('open', () => {
      probe.send(JSON.stringify({
        id: 1,
        method: 'Runtime.evaluate',
        params: {
          expression: `(() => {
            const devbar = [...document.querySelectorAll('div')]
              .filter(el => getComputedStyle(el).position === 'fixed')
              .find(el => el.innerText?.includes('Env:'));
            return !!devbar?.querySelector('div[style*="rgb(166, 240, 152)"]');
          })()`,
          returnByValue: true,
        },
      }));
    });
    probe.on('message', (d) => {
      const m = JSON.parse(d);
      if (m.id === 1) {
        clearTimeout(timeout);
        try { probe.close(); } catch {}
        resolve(m.result?.result?.value === true);
      }
    });
    probe.on('error', () => { clearTimeout(timeout); resolve(false); });
  });
}

async function pickTab() {
  const tabs = (await fetchTabs()).filter((t) => t.type === 'page' && t.url.includes('localhost:8000'));
  if (!tabs.length) throw new Error('no localhost:8000 tab found on :9222');
  if (!anyTab) {
    for (const t of tabs) {
      if (await isLeaderTab(t.webSocketDebuggerUrl)) {
        console.error(`[cdp] leader tab: ${t.title} — ${t.url}`);
        return t.webSocketDebuggerUrl;
      }
    }
    console.error('[cdp] no leader tab found; falling back to first tab (use --any to silence)');
  }
  const t = tabs[0];
  console.error(`[cdp] tab: ${t.title} — ${t.url}`);
  return t.webSocketDebuggerUrl;
}

async function main() {
  const wsUrl = await pickTab();
  const ws = new WebSocket(wsUrl);
  let id = 0;
  const pending = new Map();
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const myId = ++id;
    pending.set(myId, { resolve, reject });
    ws.send(JSON.stringify({ id: myId, method, params }));
  });

  ws.on('message', (data) => {
    const m = JSON.parse(data);
    if (m.id && pending.has(m.id)) {
      const { resolve, reject } = pending.get(m.id);
      pending.delete(m.id);
      if (m.error) reject(new Error(m.error.message));
      else resolve(m.result);
    }
  });

  ws.on('error', (e) => { console.error('ws error:', e.message); process.exit(1); });

  await new Promise((r) => ws.on('open', r));

  const params = { format: 'png' };
  if (fullPage) {
    const { contentSize } = await send('Page.getLayoutMetrics');
    params.captureBeyondViewport = true;
    params.clip = { x: 0, y: 0, width: contentSize.width, height: contentSize.height, scale: 1 };
  }

  const { data: b64 } = await send('Page.captureScreenshot', params);
  fs.writeFileSync(outPath, Buffer.from(b64, 'base64'));
  console.log(outPath);
  ws.close();
  process.exit(0);
}

main().catch((e) => { console.error(e.message); process.exit(1); });
