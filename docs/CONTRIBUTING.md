# Contributing

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Flutter | stable channel | Client + `dart pub get` |
| Dart SDK | ^3.9.2 | Included with Flutter |
| Docker | 24+ | Docker Compose for integration |

## Setup

```bash
git clone https://github.com/bearyjd/ohhell.git
cd ohhell
dart pub get          # resolves all workspace packages
```

## Project structure

```
packages/ohhell_engine/   Pure Dart game logic
packages/ohhell_protocol/ Shared wire types (client + server)
server/                   Dart WebSocket game server
client/                   Flutter app (all platforms)
```

## Available commands

<!-- AUTO-GENERATED from source files -->

| Command | Description |
|---------|-------------|
| `dart pub get` | Resolve all workspace dependencies |
| `dart run server/bin/server.dart` | Start game server on port 8080 |
| `flutter run -d linux -C client` | Run Flutter client on Linux |
| `flutter run -d android -C client` | Run Flutter client on Android |
| `flutter run -d chrome -C client` | Run Flutter client in browser |
| `dart test packages/ohhell_engine` | Engine unit tests (84) |
| `dart test packages/ohhell_protocol` | Protocol unit tests (17) |
| `dart test server` | Server integration tests (7) |
| `flutter test client` | Flutter widget + unit tests (115) |
| `dart analyze packages/ohhell_engine` | Static analysis — engine |
| `dart analyze packages/ohhell_protocol` | Static analysis — protocol |
| `dart analyze server` | Static analysis — server |
| `flutter analyze client` | Static analysis — client |
| `docker compose up` | Start server + web client via Docker |

<!-- END AUTO-GENERATED -->

## Testing

All PRs must keep tests green. Run the full suite before opening a PR:

```bash
dart test packages/ohhell_engine packages/ohhell_protocol server
flutter test client
```

Writing new tests:
- **Engine logic** → `packages/ohhell_engine/test/`
- **Protocol messages** → `packages/ohhell_protocol/test/`
- **Server integration** → `server/test/`
- **Flutter widgets/providers** → `client/test/`

## Code style

- Dart: `dart format .` (80-char lines, enforced in CI)
- No `catch (e)` — always specify exception types (`on SomeException catch (e)`)
- Immutable state throughout — use `copyWith()`, never mutate in place
- `package:` imports only — no relative `../` cross-package imports
- Files under 300 lines; split if larger

## Commit format

```
feat: add heuristic bot bid strategy
fix: prevent bid > cardsPerHand in strict mode
test: cover evaluateTrick with all-trump scenario
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`

## PR checklist

- [ ] `dart test packages/ohhell_engine packages/ohhell_protocol server` passes
- [ ] `flutter test client` passes
- [ ] `flutter analyze client` — no issues
- [ ] No hardcoded secrets or credentials
- [ ] New public API has a usage example in the relevant README
