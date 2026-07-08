---
name: Docker and platform configuration gotchas
description: Non-obvious Docker, Android, and iOS configuration requirements discovered during platform setup
type: project
---

**Docker server build context:**
The `server/Dockerfile` must be built from the repo root, not from the `server/` subdirectory:
```
docker build -f server/Dockerfile .
```
Reason: `pub get` needs the entire workspace context (root `pubspec.yaml` + all member packages). Building from `server/` breaks workspace resolution.

**Docker runtime base image:**
`FROM scratch` is incompatible with curl/wget-based healthchecks. Use `debian:bookworm-slim` as the server runtime base image when a healthcheck is needed.

**Flutter web renderer flag removed:**
`--web-renderer canvaskit` was removed in Flutter 3.27+. Use plain `flutter build web --release` — the flag causes a build error on current Flutter.

**Why:** All three were discovered as blockers during the platform config commit (commit 7 of the project).

**How to apply:** When building or modifying Docker images or CI/CD pipelines for this project, use these forms rather than the ones that look intuitive.
