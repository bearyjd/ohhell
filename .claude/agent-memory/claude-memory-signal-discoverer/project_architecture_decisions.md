---
name: Core architecture decisions
description: Settled architectural choices for the ohhell monorepo — immutable engine, sealed phases, manual Riverpod, package split
type: project
---

**Immutable GameState with sealed phases:**
The engine uses immutable `GameState` throughout — all `GameEngine` methods return a new `GameState` rather than mutating in place. `GamePhase` is a sealed class hierarchy (`Lobby`, `Dealing`, `Bidding`, `Playing`, `RoundEnd`, `GameEnd`). This was a deliberate choice to make both server and client use the same state representation safely.

**Why:** Clean architecture for concurrent server handling and predictable client state diffs. Re-litigating mutability here would break a lot of downstream code.

**Three-package split:**
- `packages/ohhell_engine` — pure Dart game logic, no Flutter/network deps
- `packages/ohhell_protocol` — shared wire types (sealed `ClientMessage`/`ServerMessage`, DTOs), used by both server and client
- `server/` — Dart shelf WebSocket server consuming both packages
- `client/` — Flutter app consuming both packages

**Why:** Keeps game logic testable in isolation (67 engine tests run with plain `dart test`), and the protocol package enforces a single source of truth for the wire format.

**No Riverpod codegen (`@riverpod`):**
The Flutter client uses manual `StateNotifierProvider` and `StateProvider` throughout — not `riverpod_generator` / `build_runner` codegen. The `riverpod_generator` and `build_runner` deps are present in `client/pubspec.yaml` but codegen was not used in practice.

**Why:** Decision made during client implementation — codegen adds build complexity for a project of this size. Do not introduce `@riverpod` annotations without first removing or reconciling the manual providers.

**How to apply:** When adding new state to the client, follow the manual provider pattern already established. When adding new game logic, add it to `ohhell_engine` and expose via the existing `GameEngine` API.
