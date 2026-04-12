# ohhell_protocol

Shared JSON wire types for the Oh Hell WebSocket protocol. Used by both the Flutter client and the Dart server.

## Features

- Sealed `ClientMessage` and `ServerMessage` types with exhaustive pattern matching
- DTO classes for serializing `GameState` without exposing opponent hands
- Full `toJson()` / `fromJson()` roundtrip support
- 17 unit tests

## Usage

### Sending a message (client)

```dart
import 'package:ohhell_protocol/ohhell_protocol.dart';
import 'dart:convert';

// Create and join a room
final msg = JoinRoomMessage(playerName: 'Alice', roomCode: null);
channel.sink.add(jsonEncode(msg.toJson()));

// Play a card
final play = PlayCardMessage(suit: 'spades', rank: 'ace');
channel.sink.add(jsonEncode(play.toJson()));
```

### Parsing incoming messages (server)

```dart
channel.stream.cast<String>().listen((raw) {
  final msg = ClientMessage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  switch (msg) {
    case JoinRoomMessage(:final playerName, :final roomCode):
      // handle join
    case PlaceBidMessage(:final bid):
      // handle bid
    case PlayCardMessage(:final suit, :final rank):
      // handle card play
    // ...
  }
});
```

### Sending game state (server)

```dart
// GameStateDto strips player hands — safe to broadcast to all
final dto = GameStateDto.fromGameState(state);
final stateMsg = GameStateMessage(state: dto);
for (final conn in connections.values) {
  conn.send(stateMsg);
}

// Send private hand only to its owner
final handMsg = YourHandMessage(
  cards: player.hand.map(CardDto.fromCard).toList(),
);
ownerConn.send(handMsg);
```

## Message types

### ClientMessage

| Class | type string | Key fields |
|-------|------------|------------|
| `JoinRoomMessage` | `join_room` | `playerName`, `roomCode?` |
| `StartGameMessage` | `start_game` | — |
| `PlaceBidMessage` | `place_bid` | `bid` |
| `PlayCardMessage` | `play_card` | `suit`, `rank` |
| `LeaveRoomMessage` | `leave_room` | — |

### ServerMessage

| Class | type string | Key fields |
|-------|------------|------------|
| `RoomJoinedMessage` | `room_joined` | `roomCode`, `playerId`, `isHost` |
| `PlayerJoinedMessage` | `player_joined` | `playerId`, `playerName` |
| `PlayerLeftMessage` | `player_left` | `playerId` |
| `GameStateMessage` | `game_state` | `state: GameStateDto` |
| `YourHandMessage` | `your_hand` | `cards: List<CardDto>` |
| `ErrorMessage` | `error` | `message` |

## Running tests

```bash
dart test packages/ohhell_protocol
```
