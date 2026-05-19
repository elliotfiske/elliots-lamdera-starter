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

## 3. Auth: Sign in with GitHub ✅

`lamdera/auth` is copy-vendored under `vendor/lamdera-auth/` and wired up for
GitHub OAuth. `src/Auth.elm` holds the config; `Types.elm` carries the
auth-related fields (`authFlow`, `authRedirectBaseUrl`, `currentUser`,
`pendingAuths`, `authenticatedSessions`); `Frontend.elm` handles
`/login/OAuthGithub/callback` and shows a "Sign in with GitHub" button.

Architectural notes:
- The Effect/raw-`Cmd` mismatch is bridged with `Effect.Command.fromCmd "auth"`
  on the backend.
- The frontend replicates `Auth.Flow.init` manually so it can use
  `Effect.Browser.Navigation` (the package's version needs a raw
  `Browser.Navigation.Key`).
- The frontend constructs `AuthCallbackReceived` directly with the callback
  URL — `Auth.Protocol.OAuth.accessTokenRequested` would have sent
  `authRedirectBaseUrl` (path `/`), causing a `redirect_uri` mismatch on the
  token exchange.
- On `ClientConnected`, the backend re-pushes `GotUser` if the session is
  already authenticated, so reloads restore the signed-in UI.
- Privacy-first: vendored `Auth.Method.OAuthGithub` is locally patched to drop
  the `user:email` scope and skip the `/user/emails` fallback. Users are
  identified by GitHub username (no email collected).

To deploy or switch GitHub OAuth Apps:
1. Register the app at https://github.com/settings/developers with
   `Authorization callback URL = <origin>/login/OAuthGithub/callback`.
2. Set `Env.githubClientId` / `Env.githubClientSecret` in `src/Env.elm` locally
   (NEVER in `Env-Clean.elm` — pre-commit hook blocks it).
3. For production, set the same values via Lamdera's environment-variable UI.

**Apple Sign-In** was the original plan; deferred. Apple's POST callback needs
an HTTP endpoint, which on Lamdera means an RPC handler — so item #2 is still
a prerequisite for that.

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

Items 1, 3, and 4 are done. Remaining:

1. **#2 RPC** — would unlock Apple Sign-In if that ever comes back on the table.
2. **#5 screenshot tooling** — orthogonal; do it whenever UI work picks up.
