# ohhell-server

Dart WebSocket game server for Oh Hell. Built with [shelf](https://pub.dev/packages/shelf) + [shelf_web_socket](https://pub.dev/packages/shelf_web_socket).

## Endpoints

| Endpoint | Protocol | Description |
|----------|----------|-------------|
| `GET /health` | HTTP | Health check — returns `ok` with 200 |
| `GET /ws` | WebSocket | Game connection endpoint |

## Running locally

```bash
# From repo root
dart pub get
dart run server/bin/server.dart
# Server listening on port 8080
```

Environment variable `PORT` overrides the default port:

```bash
PORT=9000 dart run server/bin/server.dart
```

## Running via Docker

```bash
# Build from repo root (workspace context required)
docker build -f server/Dockerfile -t ohhell-server .
docker run -p 8080:8080 ohhell-server
```

Or use Compose (starts server + Flutter web client):

```bash
docker compose up
```

## WebSocket Protocol

Connect to `ws://host:8080/ws`. All messages are JSON with a `type` discriminator and a `payload` object.

### Client → Server

| type | payload | Description |
|------|---------|-------------|
| `join_room` | `{playerName, roomCode?}` | Create (roomCode null) or join a room |
| `start_game` | `{}` | Host starts the game from lobby |
| `place_bid` | `{bid: int}` | Place bid during bidding phase |
| `play_card` | `{suit, rank}` | Play a card during playing phase |
| `leave_room` | `{}` | Leave current room |

### Server → Client

| type | payload | Description |
|------|---------|-------------|
| `room_joined` | `{roomCode, playerId, isHost}` | Assigned room and identity |
| `player_joined` | `{playerId, playerName}` | Another player joined |
| `player_left` | `{playerId}` | A player disconnected |
| `game_state` | `GameStateDto` | Full game state (no opponent hands) |
| `your_hand` | `{cards: [{suit, rank}]}` | Your private hand |
| `error` | `{message}` | Server-side error |

Suit values: `spades`, `hearts`, `diamonds`, `clubs`  
Rank values: `two`–`ten`, `jack`, `queen`, `king`, `ace`

## Running tests

```bash
dart test server
```

## Architecture

```
server/
├── bin/server.dart          ← Entry point, shelf routing
└── lib/src/
    ├── client_conn.dart     ← WebSocket wrapper per connection
    ├── room.dart            ← Room state + engine delegation
    └── room_manager.dart    ← Room lifecycle, join routing
```

Room codes are 6-character alphanumeric strings generated on creation. The server delegates all game logic to `package:ohhell_engine`.
