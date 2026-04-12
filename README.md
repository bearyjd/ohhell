# Oh Hell

Multiplayer "Oh Hell" card game built with Flutter + Dart.

## Platforms

| Platform | Build |
|----------|-------|
| Android | `flutter build apk --release` |
| iOS | `flutter build ios --release --no-codesign` |
| Windows | `flutter build windows --release` |
| Linux | `flutter build linux --release` |
| Web | `flutter build web --release` |
| Docker | `docker compose up` |

## Architecture

```
ohhell/
├── packages/
│   ├── ohhell_engine/    ← Pure Dart game logic (no UI, no network)
│   └── ohhell_protocol/  ← Shared JSON wire types (client + server)
├── client/               ← Flutter app (Android, iOS, Windows, Linux, Web)
│   ├── Dockerfile        ← Builds Flutter web → nginx image
│   └── nginx.conf        ← SPA routing + asset caching
├── server/               ← Dart shelf WebSocket game server
│   └── Dockerfile        ← Multi-stage AOT build → debian:slim image
└── docker-compose.yml    ← server + web client services
```

## Quick Start (Web / Docker)

```bash
docker compose up
# Web client: http://localhost
# Game server: ws://localhost:8080/ws
```

## Development Setup

```bash
# Prerequisites: Flutter 3.x (stable), Dart 3.9+, Docker

# Install all workspace dependencies
dart pub get

# Terminal 1 — game server
dart run server/bin/server.dart

# Terminal 2 — Flutter client (pick a platform)
flutter run -d linux -C client
flutter run -d android -C client
flutter run -d chrome -C client
```

## Running Tests

```bash
# All Dart packages
dart test packages/ohhell_engine
dart test packages/ohhell_protocol
dart test server

# Flutter client
flutter test client

# All at once
dart test packages/ohhell_engine packages/ohhell_protocol server && flutter test client
```

## Game Rules

- 3–7 players, standard 52-card deck
- Each round: deal N cards, flip trump suit
- Bid how many tricks you'll win
- Must follow suit if possible; trump beats all
- **Scoring:** +10 + bid if exact; +1 per trick taken otherwise
- Highest score after all rounds wins

## License

MIT
