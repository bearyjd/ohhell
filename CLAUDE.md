# ohhell — Claude Code Project Instructions

## gstack

- For all web browsing, use the `/browse` skill from gstack. Never use `mcp__claude-in-chrome__*` tools.
- Available gstack skills: `/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, `/design-consultation`, `/design-shotgun`, `/design-html`, `/review`, `/ship`, `/land-and-deploy`, `/canary`, `/benchmark`, `/browse`, `/connect-chrome`, `/qa`, `/qa-only`, `/design-review`, `/setup-browser-cookies`, `/setup-deploy`, `/retro`, `/investigate`, `/document-release`, `/codex`, `/cso`, `/autoplan`, `/plan-devex-review`, `/devex-review`, `/careful`, `/freeze`, `/guard`, `/unfreeze`, `/gstack-upgrade`, `/learn`

## Verified tooling and commands (agent-native audit, 2026-07-07)

Environment confirmed to have Flutter 3.44.2 / Dart 3.12.2 installed and
runnable (`flutter --version`, `dart --version`). The commands already
listed in `docs/CONTRIBUTING.md`'s auto-generated table are real and were
re-verified in this environment:

- `dart pub get` (repo root) — resolves the 4-package workspace. Confirmed working.
- `dart test packages/ohhell_engine packages/ohhell_protocol server` — **108/108 passing** (~1s) as of this audit.
- `flutter test` (run from `client/`) — **115/115 passing** (~3s) as of this audit.

Do not assume Docker/`docker compose` is available or fast in an agent
sandbox — it was not exercised in this audit (out of scope; flagged as an
open verification gap in `.agent_native/agent_roadmap.md`). Prefer the
`dart test` / `flutter test` paths above for autonomous verification loops;
they are fast and require no containers.

## Known issue: embedded-server resource leak on session leave (see `.agent_native/agent_roadmap.md` item 1)

CONFIRMED via code audit (not yet fixed as of this note). The client's
LAN-hosting embedded `HttpServer`
(`server/lib/src/embedded_server.dart` → `startEmbeddedServer()`, owned by
`client/lib/src/providers/embedded_server_native.dart`'s
`EmbeddedServerNotifier`/`embeddedServerProvider`) is only ever stopped by
the explicit "Stop Hosting" button on `home_screen.dart`. There is no
`PopScope`/back-navigation handling on `GameScreen`/`LobbyScreen`, no
`AppLifecycleState` observer anywhere in the client, and the client never
sends the protocol's own `LeaveRoomMessage` — so leaving a hosted session
by any path other than that one button leaks the listening `HttpServer`
for the remaining life of the process. Full root-cause writeup and fix
plan: `.agent_native/agent_roadmap.md`.

## Human judgment chokepoints

Codified so an agent doesn't have to guess when to ask a human first:

- **Protocol wire-format changes**: `packages/ohhell_protocol` message
  types (`ClientMessage`/`ServerMessage` in
  `packages/ohhell_protocol/lib/src/messages.dart`) have no version field
  and no documented client/server skew policy. Any change to an existing
  message's shape (not purely additive) requires a version bump plan and a
  CHANGELOG entry — do not make this call unilaterally; confirm with a
  human or flag it explicitly in the PR description.
- **Game scoring/rule edge cases**: `packages/ohhell_engine` encodes
  specific rule decisions (e.g. "strict mode" forbidding a bid equal to
  cards-per-hand — see `CHANGELOG.md` `fix: prevent bid > cardsPerHand in
  strict mode`). Before changing bidding/scoring behavior, read
  `packages/ohhell_engine/test/game_engine_test.dart` first — it is the
  authoritative spec for existing rule behavior. Treat any test change
  there as a rule-design decision requiring explicit confirmation, not a
  routine test fix.
- Install gstack: `git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup`
