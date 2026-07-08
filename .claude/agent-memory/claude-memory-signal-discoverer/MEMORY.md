# Signal Discoverer Memory Index

- [Dart workspace configuration gotchas](project_dart_workspace_gotchas.md) — resolution field, SDK caret syntax, lints version conflict in workspace members
- [Docker and platform configuration gotchas](project_docker_platform_gotchas.md) — build context, FROM scratch healthcheck limit, Flutter web renderer flag removal
- [Mobile WebSocket network permissions](project_mobile_websocket_config.md) — Android INTERNET + cleartext, iOS NSAllowsLocalNetworking for localhost dev
- [Core architecture decisions](project_architecture_decisions.md) — immutable GameState, sealed phases, 3-package split, manual Riverpod (no codegen)
- [Key dev commands for this monorepo](project_dev_commands.md) — multi-package dart test, flutter run/test -C, Docker build from root

## Agent Coverage Log

- 2026-04-12: Scanned 1 session (2026-04-12, session 8fd8f2ae). Candidates: UPDATE: 0, CONTRADICT: 0, FILL_GAP: 10, NOISE: 0. All 5 memory files written and accepted.
- 2026-04-12 (run 2): Scanned commits feat/fix: indigo/amber palette, Nunito font, CardWidget redesign, bid dialog fix, share_plus usage. Candidates: UPDATE: 0, CONTRADICT: 0, FILL_GAP: 5, NOISE: 0. Surfaced to caller for acceptance decision.
