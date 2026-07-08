---
name: Key dev commands for this monorepo
description: Non-obvious CLI commands for running tests, the Flutter client, and Docker builds from the workspace root
type: project
---

All commands run from the repo root `/var/home/user/Documents/vibe-code/games/ohhell/`.

**Run tests across multiple Dart packages in one command:**
```
dart test packages/ohhell_engine packages/ohhell_protocol server
```

**Run Flutter client tests from repo root:**
```
flutter test -C client
```

**Run Flutter client app from repo root:**
```
flutter run -C client
```
The `-C <dir>` flag points Flutter at the project directory without requiring `cd`.

**Build Docker server image (must use repo root as context):**
```
docker build -f server/Dockerfile .
```
NOT `cd server && docker build .` — the workspace pub get requires the full repo context.

**Flutter web build (current syntax):**
```
flutter build web --release
```
Do NOT use `--web-renderer canvaskit` — that flag was removed in Flutter 3.27+.

**CI test matrix (mirrors `.github/workflows/ci.yml`):**
- `dart test packages/ohhell_engine` — engine tests (67)
- `dart test packages/ohhell_protocol` — protocol tests (17)
- `dart test server` — server integration tests (4)
- `flutter analyze client` — static analysis
- `flutter test -C client` — widget/unit tests (44+)
