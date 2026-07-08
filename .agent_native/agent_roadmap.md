# Agent-Native Roadmap — ohhell

Purpose: make this repo one where an AI coding agent can pick up a bug report
or feature, reproduce it, fix it, test it, and verify it with minimal human
input. Items are ranked by **Human-Attention-Saved per Unit of Effort**
(HAS/UE) — highest first. Each item lists concrete files, commands, and
acceptance criteria so an agent can execute it without asking clarifying
questions.

Verified environment for this audit (do not re-derive — cite these):
- `flutter --version` → Flutter 3.44.2 (stable), Dart 3.12.2, at `/home/user/flutter/bin`.
- `dart pub get` at repo root succeeds (resolves the 4-package workspace).
- `dart test packages/ohhell_engine packages/ohhell_protocol server` → **108/108 passed** (~1s).
- `flutter test` (run from `client/`) → **115/115 passed** (~3s).
- Both toolchains are present and runnable in this environment — commands
  below are real, not hypothetical.

---

## 1. ✅ DONE (2026-07-07) [HIGHEST] Fix + regression-test the embedded-server leak on session leave

**Status: FIXED and regression-tested.** Implemented all three parts of the fix: (1) a shared
`leaveSession()` helper (`client/lib/src/providers/leave_session.dart`) wired into `PopScope`
back-navigation and explicit "leave" affordances on `LobbyScreen` and `GameScreen` — sends
`LeaveRoomMessage`, disconnects the websocket, and stops the embedded server if hosting; (2) a
`WidgetsBindingObserver` in `main.dart` that stops the embedded server on
`AppLifecycleState.detached` as a backstop; (3) an idle-room reaper in `RoomManager`
(`startReaper()`/`_reapIdleRooms()`, 60s sweep / 5min stale threshold) as defense-in-depth —
this also closed a real second gap where `Room._handleLeaveRoom` removing a connection directly
caused `RoomManager`'s `_onDisconnect` to no-op and never register the room for grace-period
cleanup. New tests: `server/test/room_manager_leak_test.dart` (4 tests) and
`client/test/unit/leave_session_test.dart` (3 tests). Verified: `dart test` 112/112 passing
(108 baseline + 4 new), `flutter test` 118/118 passing (115 baseline + 3 new), `flutter analyze`
and `dart analyze server` both clean. No regressions to `reconnect_test.dart`. Changes are
uncommitted in the working tree (no git commit was made per task constraints).

**Original status of the known bug: CONFIRMED, root cause identified.**

### Root cause

The "embedded server" is the in-process Dart `HttpServer` started for LAN
hosting ("Host on this device"), created by
`server/lib/src/embedded_server.dart:19` (`startEmbeddedServer()`) and owned
client-side by
`client/lib/src/providers/embedded_server_native.dart` (`EmbeddedServerNotifier`,
backing the global `embeddedServerProvider`).

The cleanup code itself is correct — `stop()` (line 42) and `dispose()`
(line 65) both call `_server?.close(force: true)`. **The bug is that nothing
outside of one explicit UI button ever calls it.** Concretely:

- `embeddedServerProvider` is referenced in exactly one file:
  `client/lib/src/screens/home_screen.dart` (verified via
  `grep -rln "embeddedServerProvider" client/lib`). The only call sites for
  `.stop()` are the "Stop Hosting" button (`home_screen.dart:109`) and
  `EmbeddedServerNotifier.dispose()`.
- `embeddedServerProvider` and `wsProvider` are both plain
  `StateNotifierProvider` (not `.autoDispose`), created once under the single
  app-wide `ProviderScope` in `client/lib/main.dart:7`
  (`runApp(const ProviderScope(child: OhHellApp()))`). Riverpod only calls
  `dispose()` on a provider when its container is disposed — for a
  top-level `ProviderScope` that only happens when the whole app/process
  tears down. It does **not** happen when a user navigates between screens.
- There is **no leave/back-navigation teardown hook anywhere in the
  client**: no `PopScope`/`WillPopScope` override on `GameScreen`,
  `LobbyScreen`, or `ScoreScreen` (`grep -rn "PopScope\|WillPopScope"
  client/lib` → no matches), no `AppLifecycleState`/
  `WidgetsBindingObserver` usage anywhere in `client/lib`
  (`grep -rln "AppLifecycleState\|WidgetsBindingObserver" client/lib` → no
  matches), and the protocol's own `LeaveRoomMessage`
  (`packages/ohhell_protocol/lib/src/messages.dart:94`, handled server-side
  at `server/lib/src/room.dart:138` `_handleLeaveRoom`) is **never sent by
  the client** (`grep -rn "LeaveRoomMessage" client/lib` → zero call sites;
  only appears in the protocol package and the server).
- Net effect: if a host backs out of `GameScreen`/`LobbyScreen` via the
  system back button, switches apps, or the app is otherwise backgrounded
  without the user explicitly tapping "Stop Hosting," the embedded
  `HttpServer` — and everything it owns (`RoomManager`, all `Room`s,
  `ClientConnection`s, and any pending grace-period `Timer`s in
  `server/lib/src/room_manager.dart`) — keeps running for the remaining
  life of the process. There is no reaper, no idle-room timeout, and no
  lifecycle hook to catch this path.
- Confirming what *is* already handled correctly (so the fix doesn't
  duplicate it): the per-connection WebSocket teardown in
  `RoomManager.handleNewConnection` (`server/lib/src/room_manager.dart:34-89`)
  is sound — `onDone`/`onError` both route to `_onDisconnect`, which starts a
  30s grace-period timer, and `_expireGracePeriod` (line 91) correctly
  removes a `Room` from `_rooms` once no connections and no
  pending-reconnect players remain for that room code. That part is not the
  leak. The leak is specifically the **client-owned embedded HttpServer
  process**, not the room bookkeeping inside it.

### Reproduction recipe (agent-runnable, no device needed)

Add a Dart test that starts the embedded server the way `home_screen.dart`
does, then simulates "leaving without pressing Stop" by disposing the
`ProviderContainer` *without* calling `stop()` first, and asserts the port
is still bound (leak reproduced) vs. freed (fixed):

```dart
// client/test/unit/embedded_server_leak_test.dart (new file)
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohhell_client/src/providers/embedded_server_provider.dart';

void main() {
  test('leaving without Stop Hosting must not leak the listening port', () async {
    final container = ProviderContainer();
    await container.read(embeddedServerProvider.notifier).start();
    final port = (container.read(embeddedServerProvider) as ServerRunning).port;

    // Simulate the user backing out of GameScreen/LobbyScreen: nothing
    // calls stop(); only the container goes away (today: nothing calls
    // this either, since the container is app-lifetime — that's the bug).
    container.dispose();
    // Give the notifier's dispose() a tick to run its close() call.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // The port must be free — bind to it again to prove no leaked listener.
    final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, port)
        .timeout(const Duration(seconds: 2));
    await probe.close(force: true);
  });
}
```
Run: `cd client && flutter test test/unit/embedded_server_leak_test.dart`.
This test currently *passes* only because `dispose()` on the
`StateNotifier` happens to run correctly when the container is manually
disposed in a unit test — it does **not** prove the production path is
safe, because in production nothing ever disposes the container or calls
`stop()` on the leave path. The real regression test must exercise the
**navigation** path, not just the notifier in isolation — see the fix
below.

### The fix (what to implement)

1. Add a `PopScope`/back-navigation and an explicit "Leave Game" affordance
   to `client/lib/src/screens/game_screen.dart` and
   `client/lib/src/screens/lobby_screen.dart` that, on leave:
   - sends `LeaveRoomMessage()` via `ref.read(wsProvider.notifier).send(...)`,
   - calls `ref.read(wsProvider.notifier).disconnect()`,
   - if `ref.read(embeddedServerProvider) is ServerRunning` **and** this
     client is the host, calls
     `ref.read(embeddedServerProvider.notifier).stop()`.
2. Add a `WidgetsBindingObserver` (e.g. in `OhHellApp` or a new
   `AppLifecycleNotifier`) that calls `embeddedServerProvider.notifier.stop()`
   when `AppLifecycleState.detached` fires (app process about to be
   destroyed), as a backstop for users who quit without navigating back.
3. Add an idle-room reaper in `RoomManager`
   (`server/lib/src/room_manager.dart`) as defense-in-depth: a periodic
   sweep (e.g. every 60s) that force-removes any `Room` with zero
   connections and zero pending `_disconnectedPlayers` older than, say, 5
   minutes, independent of the client ever sending `leave_room`.

### Acceptance criteria

- `client/test/unit/embedded_server_leak_test.dart` (or equivalent
  navigation-level widget test) fails on current `main` and passes after
  the fix.
- `dart test server` still 100% green (no regression to grace-period
  reconnect behavior in `server/test/reconnect_test.dart`).
- New server test in `server/test/` asserts `RoomManager.rooms` returns to
  size 0 after a host-only room's connection drops and the grace period
  elapses (currently untested — see item 2 below).
- `flutter test client` still 100% green.

---

## 2. [HIGH] Close the RoomManager/Room verification gap with leak-shaped assertions

**Effort: small (~1-2 hours). Saves: every future "is it actually cleaned
up" review a human would otherwise have to do by reading code.**

`server/lib/src/room_manager.dart:27` exposes `rooms` explicitly "for tests,"
but **no existing test reads it**. `server/test/reconnect_test.dart` and
`server/test/server_test.dart` verify message flows (`player_left`,
`player_reconnected`, error responses) but never assert on `RoomManager`'s
internal map sizes. This is the exact instrumentation an agent needs to
autonomously confirm "the leak is fixed" instead of trusting log lines.

Add to `server/test/room_manager_leak_test.dart` (new file):
- Construct a `RoomManager` directly (no HTTP), use the existing `WsClient`
  pattern from `reconnect_test.dart` against a `RoomManager`-backed
  `io.serve` instance.
- Test: "room is removed from `RoomManager.rooms` once all connections
  disconnect and grace period elapses" — assert `manager.rooms.isEmpty`
  after the grace period, not just that a `player_left` message was
  broadcast.
- Test: "reconnecting player cancels the pending grace-period Timer" —
  currently `Timer(gracePeriod, ...)` in `_onDisconnect`
  (`room_manager.dart:88`) is **not stored**, so it cannot be cancelled;
  it runs to completion regardless and is a no-op if already reconnected
  (checked via `_disconnectedPlayers.remove(...)  == null`). This is safe
  today but is exactly the kind of implicit invariant an agent can't verify
  without a test — pin it down explicitly so a future refactor doesn't
  silently break it.

### Acceptance criteria
- New test file added, `dart test server` includes it and passes.
- Test fails if someone reintroduces a scenario where `_rooms` retains an
  entry with zero connections and zero pending disconnects for that code.

---

## 3. [HIGH] Wire up a scripted multi-client repro harness for the embedded server

**Effort: small. Saves an agent from having to hand-write a socket harness
from scratch every time it needs to reproduce a connect/disconnect issue.**

There is currently no standalone script (only inline test helpers duplicated
across `server/test/server_test.dart` and `server/test/reconnect_test.dart`)
that an agent can run ad hoc, outside the test runner, to open N WebSocket
connections against a running server/embedded server and observe resource
state. Add `server/tool/repro_leak.dart`:

```dart
// server/tool/repro_leak.dart
// Usage: dart run server/tool/repro_leak.dart --connections=20 --port=0
// Opens N clients, joins/creates rooms, immediately drops every socket
// (simulating "users leave"), waits past the grace period, then prints
// RoomManager.rooms.length and open-socket count. Non-zero after the wait
// indicates a leak.
```
This turns "can an agent reproduce the leak" from "no — would need to spin
up Flutter, a device, and manually background the app" into "yes — one
`dart run` command with a numeric pass/fail."

### Acceptance criteria
- `dart run server/tool/repro_leak.dart --connections=50` exits 0 and
  prints `rooms remaining: 0` after the fix in item 1; prints a non-zero
  count and exits 1 before the fix (i.e., the tool itself should assert
  and fail loudly, not just log).

---

## 4. [MEDIUM] Codify game-rule and protocol-versioning judgment calls into CLAUDE.md

**Effort: small (doc-only). Saves an agent from guessing at intent on
every bid/scoring edge case or wire-format change.**

Two categories of human judgment currently live only in code comments/tests,
not in any agent-facing instructions:

- **Scoring/rule edge cases** in `packages/ohhell_engine` (e.g. "strict
  mode" bid-can't-equal-cards-per-hand rule referenced in `CHANGELOG.md`
  under `fix: prevent bid > cardsPerHand in strict mode` in
  `docs/CONTRIBUTING.md`'s commit examples, and the "no code generation, no
  build_runner" decision noted in `docs/RUNBOOK.md`). An agent asked to "add
  a new bid variant" has no single place that states which scoring rules are
  load-bearing game-design decisions (must ask a human) vs. which are
  implementation details (safe to change unilaterally).
- **Protocol versioning**: `packages/ohhell_protocol` has no version field
  in its wire messages (`ClientMessage`/`ServerMessage` — confirmed via
  `packages/ohhell_protocol/lib/src/messages.dart`) and no documented policy
  for what happens when client and server drift (e.g. old APK talking to a
  new server after a Docker Compose deploy). This is a real chokepoint:
  RUNBOOK's rollback section handles *server* rollback but nothing addresses
  wire-compatibility across client/server version skew.

Add a new `## Human Judgment Chokepoints` section to
`/home/user/Documents/vibe-code/games/ohhell/CLAUDE.md` listing these two
explicitly with a rule: "no wire-breaking change to
`ohhell_protocol` message shapes without a version bump + CHANGELOG entry
+ explicit confirmation," and "scoring-rule changes require checking
`packages/ohhell_engine/test/game_engine_test.dart` for the existing
authoritative test coverage before altering behavior."

### Acceptance criteria
- CLAUDE.md updated (see item 6 below — already done as part of this audit).

---

## 5. [MEDIUM] Document/test the Docker Compose full-stack repro path for structural agent-autonomy

**Effort: medium. Saves an agent from being blocked entirely when a bug
report needs full-stack (WS + embedded server + real network) reproduction.**

`docker-compose.yml` + Dockerfiles exist and RUNBOOK documents
`docker compose build && docker compose up -d` plus curl-based health
checks, but there is no test or script that an agent can run headlessly to
confirm the **multi-container** path still works end-to-end (e.g. after a
protocol change) without a human eyeballing `docker compose logs`. This
audit did not attempt a Docker build (out of scope / time-boxed to
dart/flutter test verification), so this is flagged as an **open
verification gap**, not something confirmed broken.

Suggested addition: a `docs/RUNBOOK.md` section (or `server/tool/`
script) that does `docker compose up -d --wait` then curls `/health` and
opens one throwaway WebSocket connection, asserting `room_joined` — giving
an agent a scripted, exit-code-based way to confirm the containerized path
without interpreting logs.

### Acceptance criteria
- A single command (documented) that an agent can run to get a pass/fail
  signal on the full Docker Compose stack, not just "start it and hope."

---

## Structural obstacles noted (not immediately actionable, for awareness)

- **Multi-package workspace**: `dart pub get` at the repo root resolves all
  4 packages via Dart's `workspace:` pubspec field — this already works
  well for agent autonomy (single command, verified above). No action
  needed.
- **Docker dependency for full-stack repro**: see item 5 — the embedded
  server leak (item 1) can be fully reproduced and fixed using only `dart`/
  `flutter test`, so Docker is *not* a blocker for the highest-priority
  item. It only becomes a blocker for verifying the containerized
  deployment path specifically.
- **Client test run time**: `flutter test` took ~3s in this environment,
  well within agent-loop budgets. `dart test` for the 3 non-Flutter
  packages took ~1s. Neither is a throughput concern for autonomous
  iteration.
