# lamdera-starter — Claude notes

## Debugging frontend/backend state via Chrome DevTools Protocol

Lamdera's official Chrome extension/MCP is blocked at the org level, so we tail
the browser console over CDP directly. This gives Claude (or anyone) read-only
access to `console.log` output without any extension.

### One-time setup

Launch a **separate** debuggable Chrome instance so your normal browser/profile
stays untouched:

```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-debug \
  http://localhost:8000
```

Run `lamdera live` as usual in another terminal.

### Tailing logs

```bash
node scripts/cdp-console.js 10           # listen for 10 seconds
node scripts/cdp-console.js 30 ws://...  # override tab WS URL
```

Auto-picks the first `localhost:8000` tab. To list tabs manually:

```bash
curl -s http://localhost:9222/json | jq '.[] | select(.type=="page") | {title,url,webSocketDebuggerUrl}'
```

CDP only streams events going forward — to capture init-time logs, reload the
page *after* the listener is running (or trigger reload via
`Runtime.evaluate { expression: "location.reload()" }`).

### Leader tab (where the backend lives)

In Lamdera dev, the backend runs in **one specific tab** — the "leader" — not
in the terminal. Backend `Debug.log` output and all `ToBackend`/`BackendMsg`
traces only appear in that tab's console. Visually it's the tab with the small
green dot on the Lamdera devbar (bottom-left).

The script auto-prefers the leader when multiple `localhost:8000` tabs are
open. Detection: scan the fixed-position devbar for a child `div` styled with
`background-color: rgb(166, 240, 152)`. If you close the leader tab, another
tab is promoted — re-run the script to re-detect.

If only one tab is open, it's always the leader.

### Evaluating JS in the leader tab

For one-shot inspection / triggering actions, use the eval companion script:

```bash
node scripts/cdp-eval.js "document.title"
node scripts/cdp-eval.js "location.reload(); 'reloading'"
node scripts/cdp-eval.js "({url: location.href, ls: Object.keys(localStorage)})"
echo "(async () => { ... })()" | node scripts/cdp-eval.js -      # stdin
node scripts/cdp-eval.js --any "1+1"                              # skip leader check
```

Multi-statement scripts work; the last expression's value is returned. For
async, wrap in `(async () => { ... })()` — `awaitPromise` is on by default.
Objects are auto-JSON-stringified. Exceptions print to stderr with exit code 1.

### Screenshots and rendered HTML

For UI iteration, capture the live (post-Elm-init) DOM as a PNG or HTML:

```bash
node scripts/cdp-screenshot.js                          # → /tmp/lamdera-screenshot.png
node scripts/cdp-screenshot.js --full-page              # capture beyond viewport
node scripts/cdp-screenshot.js --out shot.png           # custom path
node scripts/cdp-html.js                                # full document → stdout
node scripts/cdp-html.js --selector '[data-testid="x"]' # outerHTML of one node
node scripts/cdp-html.js --out page.html                # write to file
```

Both auto-pick the leader tab (`--any` to skip). The screenshot script prints
the output path on stdout so the Read tool can open the PNG directly. Use
`cdp-html.js` instead of `curl localhost:8000` when you need post-render
output — the curl response is just Lamdera's bootstrap shell.

### What Lamdera already logs for free

In dev mode, Lamdera pipes a lot of state into the browser console with no
`Debug.log` needed:

| Prefix | Meaning |
|---|---|
| `☀️ Initializing new app: "..."` | Fresh frontend init |
| `☀️ Restored BackendModel: { ... }` | Backend state snapshot on reload |
| `❇️ ReceivedBackendModel: { ... }` | Backend model sent over wire |
| `F   : <msg>` | FrontendMsg dispatched |
| `F▶️  : <msg>` | Frontend → Backend send |
| ` ▶️B : <msg>` | Backend receives ToBackend |
| `  B : <msg>` | BackendMsg dispatched |
| ` ◀️B : <msg>` | Backend → Frontend send |
| `F◀️  : <msg>` | Frontend receives ToFrontend |

So for read-only inspection of `BackendModel`, `FrontendModel`, or any msg
flowing between them, **just attach the listener** — no source edits needed.

### `Debug.log` escape hatch

For values *not* in the model (e.g. mid-update derived state), add `Debug.log`
inside `update` so it fires on each msg:

```elm
update msg model =
    let _ = Debug.log "msg" msg in
    case msg of ...
```

Logging in `view` is noisier and Elm may DCE a `let _ = Debug.log ...` whose
result is unused; if that happens, bind the result and thread it into the
output (e.g. via `always`).

**Gotcha:** `lamdera live` is started manually by the user. Its cwd may be a
worktree, not the main checkout. If your `Debug.log` edit compiles on disk but
never fires in the browser, check `lsof -p $(pgrep -f 'lamdera live') | grep cwd`
and edit there instead.

## Other conventions

- Backlog lives in [TODO.md](TODO.md).
- E2E tests run via `npm test`.
- `src/Env.elm` is guarded by a pre-commit hook against secret leaks
  ([.githooks](.githooks/)).
- `elm-review` runs on file edits via a `PostToolUse` hook in
  [.claude/settings.json](.claude/settings.json).
