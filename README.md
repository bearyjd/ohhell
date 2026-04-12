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
├── client/               ← Flutter app (all platforms)
├── server/               ← Dart shelf WebSocket game server
└── docker/               ← Dockerfiles + nginx config
```

## Quick Start (Web / Docker)

```bash
# Build Flutter web
cd client && flutter build web --release && cd ..

# Start server + web client
docker compose up
# Open http://localhost
```

## Development Setup

```bash
# Prerequisites: Flutter 3.x, Dart 3.x, Docker

# Install dependencies (all packages)
dart pub get          # root workspace
cd client && flutter pub get

# Run game server locally
cd server && dart run bin/server.dart

# Run Flutter client (Linux desktop)
cd client && flutter run -d linux \
  --dart-define=SERVER_HOST=localhost \
  --dart-define=SERVER_PORT=8080
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
