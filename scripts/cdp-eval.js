#!/usr/bin/env node
// Evaluate a JS expression in a Lamdera tab via Chrome DevTools Protocol.
//
// Prereqs: same as cdp-console.js (debuggable Chrome on :9222, `npm install`).
//
// Usage:
//   node scripts/cdp-eval.js "document.title"
//   node scripts/cdp-eval.js "location.reload(); 'reloading'"
//   echo "1+2" | node scripts/cdp-eval.js -            # read expression from stdin
//   node scripts/cdp-eval.js --any "document.title"    # don't insist on leader tab
//
// Auto-picks the Lamdera leader tab by default. Wraps the expression in an
// IIFE so multi-statement scripts work and `const`/`let` are scoped. Awaits
// promises automatically.

const http = require('http');
const WebSocket = require('ws');

const args = process.argv.slice(2);
const anyTab = args.includes('--any');
const exprArg = args.filter((a) => a !== '--any')[0];
if (!exprArg) { console.error('usage: cdp-eval.js [--any] <expression|->'); process.exit(1); }

async function readExpr() {
  if (exprArg !== '-') return exprArg;
  return new Promise((resolve) => {
    let buf = '';
    process.stdin.on('data', (c) => buf += c);
    process.stdin.on('end', () => resolve(buf));
  });
}

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

function formatResult(r) {
  if (!r) return 'null';
  if (r.type === 'string') return r.value;
  if (r.value !== undefined) return JSON.stringify(r.value, null, 2);
  if (r.unserializableValue) return r.unserializableValue;
  return r.description ?? r.type;
}

async function main() {
  // CDP's Runtime.evaluate handles multi-statement scripts natively and
  // returns the completion value of the last expression-statement.
  // For async code, the user should wrap in `(async () => { ... })()`.
  const expression = (await readExpr()).trim();
  const wsUrl = await pickTab();
  const ws = new WebSocket(wsUrl);

  ws.on('open', () => {
    ws.send(JSON.stringify({
      id: 1,
      method: 'Runtime.evaluate',
      params: { expression, returnByValue: true, awaitPromise: true },
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
    console.log(formatResult(m.result?.result));
    ws.close();
    process.exit(0);
  });

  ws.on('error', (e) => { console.error('ws error:', e.message); process.exit(1); });
}

main().catch((e) => { console.error(e.message); process.exit(1); });
