#!/usr/bin/env node
// Dump the post-Elm-init HTML of a Lamdera tab via Chrome DevTools Protocol.
//
// Prereqs: same as cdp-console.js (debuggable Chrome on :9222, `npm install`).
//
// Usage:
//   node scripts/cdp-html.js                            # → stdout
//   node scripts/cdp-html.js --out page.html            # write to file (prints path)
//   node scripts/cdp-html.js --selector '[data-testid="message"]'  # outerHTML of a node
//   node scripts/cdp-html.js --any                      # don't insist on leader tab
//
// Unlike `curl localhost:8000`, this returns the DOM *after* the Elm runtime
// has rendered, so client-side view output is included.

const http = require('http');
const path = require('path');
const fs = require('fs');
const WebSocket = require('ws');

const args = process.argv.slice(2);
const anyTab = args.includes('--any');
const outIdx = args.indexOf('--out');
const outPath = outIdx >= 0 ? path.resolve(args[outIdx + 1]) : null;
const selIdx = args.indexOf('--selector');
const selector = selIdx >= 0 ? args[selIdx + 1] : null;

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

  // Build the expression. JSON-stringify the selector to escape it safely.
  const expression = selector
    ? `(() => { const el = document.querySelector(${JSON.stringify(selector)}); if (!el) throw new Error('selector not found: ' + ${JSON.stringify(selector)}); return el.outerHTML; })()`
    : `document.documentElement.outerHTML`;

  ws.on('open', () => {
    ws.send(JSON.stringify({
      id: 1,
      method: 'Runtime.evaluate',
      params: { expression, returnByValue: true },
    }));
  });

  ws.on('message', (d) => {
    const m = JSON.parse(d);
    if (m.id !== 1) return;
    if (m.result?.exceptionDetails) {
      const e = m.result.exceptionDetails;
      console.error(`[exception] ${e.text} ${e.exception?.description || ''}`);
      ws.close();
      process.exit(1);
    }
    const html = m.result?.result?.value ?? '';
    if (outPath) {
      fs.writeFileSync(outPath, html);
      console.log(outPath);
    } else {
      process.stdout.write(html);
      if (!html.endsWith('\n')) process.stdout.write('\n');
    }
    ws.close();
    process.exit(0);
  });

  ws.on('error', (e) => { console.error('ws error:', e.message); process.exit(1); });
}

main().catch((e) => { console.error(e.message); process.exit(1); });
