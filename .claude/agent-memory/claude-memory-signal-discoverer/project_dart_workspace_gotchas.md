---
name: Dart workspace configuration gotchas
description: Non-obvious requirements for Dart workspace monorepo setup in this project — version constraints, resolution field, lints conflict
type: project
---

Three gotchas discovered through trial-and-error when setting up the Dart workspace:

1. **`resolution: workspace` must appear in every member pubspec** — not just the root. Required in `client/pubspec.yaml`, `packages/ohhell_engine/pubspec.yaml`, `packages/ohhell_protocol/pubspec.yaml`, and `server/pubspec.yaml`.

2. **Root pubspec SDK constraint must use caret syntax** — `sdk: "^3.9.2"` not `">=3.0.0 <4.0.0"`. The workspace feature requires the newer caret form; the range form silently fails to activate workspace resolution.

3. **`lints: ^6.0.0` conflicts with `flutter_lints: ^5.0.0`** — `flutter_lints` pins `lints` to `^5.0.0`. Any non-Flutter Dart package (`ohhell_engine`, `ohhell_protocol`, `server`) that uses `lints: ^6.0.0` (the dart create default) will break workspace pub resolution. Fix: downgrade to `lints: ^5.0.0` in all non-Flutter packages.

**Why:** All three were discovered as blockers during initial workspace scaffold. The dart create tool generates incompatible defaults that must be manually corrected.

**How to apply:** When adding a new Dart package to this workspace, immediately set `resolution: workspace`, verify SDK constraint is `^3.9.2`, and set `lints: ^5.0.0` (not `^6.0.0`).
