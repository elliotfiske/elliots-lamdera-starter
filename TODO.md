# Lamdera Starter — To-Do

A checklist of foundational pieces to set up in this starter project. Items are
independent enough that each can be tackled in a separate session with fresh
context — see the "Context for a fresh session" notes under each item.

---

## 1. Basic E2E test using `lamdera/program-test` ✅

Wired up. `tests/E2ETests.elm` drives a Ping/Pong round-trip (click button →
`ToBackend` → `ToFrontend` → message updates) and asserts the view via
`data-testid="message"`.

Run with `npm test` (which invokes `elm-test-rs --compiler $(which lamdera)`).

---

## 2. RPC calls

Set up the Lamdera RPC pattern so the frontend (or external clients) can call
typed backend endpoints over HTTP.

**Context for a fresh session**
- Lamdera RPC uses an `RPC.elm` module that registers handlers; see the old
  dashboard's `OLD-dashboard/src/RPC.elm` and `OLD-dashboard/src/LamderaRPC.elm`
  in git history (`git show bbdb147 -- OLD-dashboard/src/RPC.elm` once they're
  committed, or check `git log --all` for the deletion commit).
- Decide whether the first RPC is called from the Elm frontend or from an
  external HTTP client — the calling pattern differs.
- Reference: https://dashboard.lamdera.app/docs/rpc

---

## 3. Auth: Sign in with Apple

Add Sign in with Apple as the auth provider.

**Context for a fresh session**
- Apple's OAuth flow requires: an Apple Developer account, a Services ID, a
  configured Return URL pointing at the deployed Lamdera app, and a signing key
  (.p8) used to mint client secrets (JWT signed with ES256).
- Decisions to make up front:
  - Session storage: server-side session token in BackendModel keyed by a
    cookie, vs. encoded JWT round-tripped to the client.
  - Whether to use `form_post` response mode (Apple POSTs to your return URL)
    vs. `query` — `form_post` is required if you ask for `name`/`email` scopes.
- Reference implementations worth comparing:
  - https://github.com/jxxcarlson/kitchen-sink (has an auth setup, though may be
    Google/email-based)
  - https://developer.apple.com/documentation/sign_in_with_apple
- Lamdera-specific: Apple's POST callback hits an HTTP endpoint, which on
  Lamdera means an RPC handler (see item #2) — so item #2 is effectively a
  prerequisite.

---

## 4. `elm-review` configuration ✅

Wired up. Config in `review/src/ReviewConfig.elm` (based on kitchen-sink).
Run with `npm run review`.

Lamdera-specific adjustments:
- `NoUnused.Exports` ignores Lamdera's four magic modules (`Backend`,
  `Frontend`, `Types`, `Env`) because Lamdera's runtime introspects `app`
  without any Elm code calling it. `NoExposingEverything` and
  `NoImportingEverything` apply globally — the magic modules use narrow
  explicit exposing lists (`app`, `app_`, and the wire types).
- `NoUnused.Dependencies` is disabled because Lamdera regenerates `elm.json`
  and keeps `elm/browser` / `elm/bytes` in `direct` regardless.
- The npm script does NOT pass `--compiler $(which lamdera)` — Lamdera's
  compiler chokes on `elm-review-simplify`. Vanilla `elm` (already installed)
  compiles the review config fine.

---

## 5. Skill/tool for iterating on the `lamdera live` dashboard

Goal: let Claude quickly grab a screenshot or the rendered HTML of the
hot-reloading `lamdera live` dev server (default http://localhost:8000) so it
can iterate on UI changes without round-tripping through the user.

**Context for a fresh session**
- `lamdera live` serves a normal web page — for HTML, a simple `curl
  http://localhost:8000` may suffice for static markup, but client-rendered Elm
  apps will need a headless browser to get post-`init` DOM.
- Options to evaluate:
  1. **Headless Chrome via `chrome-devtools` or Playwright CLI** — most robust;
     can produce both screenshots and serialized DOM after Elm runtime has
     executed.
  2. **A tiny Chrome extension** that exposes a local endpoint Claude can hit
     to dump the active tab's HTML/screenshot. Useful if the user already has
     the page open during dev.
  3. **A custom Claude Code skill** wrapping option 1 or 2, registered in
     `.claude/skills/` so it's invokable as `/lamdera-screenshot` or similar.
- Recommended path: start with Playwright (option 1) wrapped as a skill — no
  browser extension install needed, works headlessly in CI too.
- Reference: `~/.claude/skills/` for the skill format, and the
  `toolsmith:creating-skills` skill.

---

## Suggested order

1. **#4 elm-review** — quickest win, no architectural decisions.
2. **#1 program-test** — forces the `Effect`-based refactor of Frontend/Backend
   which everything else benefits from.
3. **#2 RPC** — prerequisite for #3.
4. **#5 screenshot tooling** — orthogonal; do it whenever UI work picks up.
5. **#3 Sign in with Apple** — most external moving parts; do last when the
   foundation is stable.
