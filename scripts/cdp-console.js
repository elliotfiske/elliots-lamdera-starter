#!/usr/bin/env node
// Tail console messages from a Chrome tab via the DevTools Protocol.
//
// Prereqs:
//   1. Launch a debuggable Chrome (separate profile so your normal browser is undisturbed):
//        /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
//          --remote-debugging-port=9222 \
//          --user-data-dir=/tmp/chrome-debug \
//          http://localhost:8000
//   2. `npm install` at the repo root (provides `ws`).
//
// Usage:
//   node scripts/cdp-console.js [duration-seconds] [ws-url-override]
//
// Auto-picks the first http://localhost:8000 tab.

const http = require('http');
const WebSocket = require('ws');

const duration = parseFloat(process.argv[2] || '10') * 1000;
const wsOverride = process.argv[3];

const fetchTabs = () => new Promise((resolve, reject) => {
  http.get('http://localhost:9222/json', (res) => {
    let body = '';
    res.on('data', (c) => body += c);
    res.on('end', () => { try { resolve(JSON.parse(body)); } catch (e) { reject(e); } });
  }).on('error', reject);
});

// Probe a tab via a short-lived WebSocket: is it the Lamdera leader (green dot in devbar)?
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
  if (wsOverride) return wsOverride;
  const tabs = (await fetchTabs()).filter((t) => t.type === 'page' && t.url.includes('localhost:8000'));
  if (!tabs.length) throw new Error('no localhost:8000 tab found on :9222');
  // Prefer the Lamdera leader tab (only one has the backend; sees backend Debug.logs + ToBackend traces)
  for (const t of tabs) {
    if (await isLeaderTab(t.webSocketDebuggerUrl)) {
      console.error(`[cdp] attaching to leader tab: ${t.title} — ${t.url}`);
      return t.webSocketDebuggerUrl;
    }
  }
  const t = tabs[0];
  console.error(`[cdp] no leader tab detected; attaching to: ${t.title} — ${t.url}`);
  return t.webSocketDebuggerUrl;
}

function fmtArg(a) {
  if (a.value !== undefined) return typeof a.value === 'string' ? a.value : JSON.stringify(a.value);
  if (a.unserializableValue) return a.unserializableValue;
  return a.description ?? a.type;
}

async function main() {
  const wsUrl = await pickTab();
  const ws = new WebSocket(wsUrl);
  let id = 0;
  const send = (method, params = {}) => ws.send(JSON.stringify({ id: ++id, method, params }));

  ws.on('open', () => {
    send('Runtime.enable');
    send('Log.enable');
  });

  ws.on('message', (data) => {
    const msg = JSON.parse(data);
    if (msg.method === 'Runtime.consoleAPICalled') {
      const { type, args, stackTrace } = msg.params;
      const loc = stackTrace?.callFrames?.[0];
      const where = loc ? `${(loc.url || '').split('/').pop()}:${loc.lineNumber + 1}` : '';
      console.log(`[${type}] ${args.map(fmtArg).join(' ')}${where ? '  (' + where + ')' : ''}`);
    } else if (msg.method === 'Runtime.exceptionThrown') {
      const e = msg.params.exceptionDetails;
      console.log(`[exception] ${e.text} ${e.exception?.description || ''}`);
    } else if (msg.method === 'Log.entryAdded') {
      const e = msg.params.entry;
      console.log(`[log/${e.level}] ${e.text}`);
    }
  });

  ws.on('error', (e) => { console.error('ws error:', e.message); process.exit(1); });
  setTimeout(() => { ws.close(); process.exit(0); }, duration);
}

main().catch((e) => { console.error(e.message); process.exit(1); });
