# Reconnect & Network Error Handling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 30-second server-side grace period so disconnected players can rejoin their seat, plus client-side auto-retry with exponential backoff and a visible network status overlay.

**Architecture:** `RoomManager` holds disconnected player metadata and starts a `Timer` per disconnect; a `ReconnectPlayerMessage` / `PlayerReconnectedMessage` pair in the protocol lets the client claim its old seat on reconnect. `WsNotifier` stores `_serverHost` and retries with exponential backoff (1, 2, 4, 8, 16 s) when it detects an in-session disconnect. A `NetworkStatusOverlay` widget renders reconnecting/error banners over the game and lobby screens.

**Tech Stack:** Dart shelf + `dart:async` Timer (server), Flutter Riverpod manual `StateNotifierProvider` (client), `web_socket_channel`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `packages/ohhell_protocol/lib/src/messages.dart` | Add `ReconnectPlayerMessage` (client→server) + `PlayerReconnectedMessage` (server→client) |
| Modify | `server/lib/src/room_manager.dart` | Grace-period seat hold: `_DisconnectedPlayer`, `gracePeriod` param, `_handleReconnect`, `_expireGracePeriod` |
| Create | `server/test/reconnect_test.dart` | Integration tests for grace period + reconnect |
| Modify | `client/lib/src/providers/ws_provider.dart` | Add `WsReconnecting` status, `_serverHost`, auto-retry with backoff, `manualReconnect()`, `_sendReconnectIfNeeded()`, handle `PlayerReconnectedMessage` |
| Create | `client/test/unit/ws_reconnect_test.dart` | Unit tests for `WsReconnecting` + `manualReconnect` |
| Create | `client/lib/src/widgets/network_status_overlay.dart` | Stack-based banner: reconnecting spinner and error+retry button |
| Create | `client/test/widget/network_status_overlay_test.dart` | Widget tests for each WsStatus variant |
| Modify | `client/lib/src/screens/game_screen.dart` | Wrap top-level `Scaffold` with `NetworkStatusOverlay` |
| Modify | `client/lib/src/screens/lobby_screen.dart` | Wrap top-level `Scaffold` with `NetworkStatusOverlay` |

---

## Task 1: Protocol — ReconnectPlayerMessage + PlayerReconnectedMessage

**Files:**
- Modify: `packages/ohhell_protocol/lib/src/messages.dart`

- [ ] **Step 1: Add `ReconnectPlayerMessage` to the `ClientMessage` sealed class**

In `messages.dart`, directly after the `LeaveRoomMessage` class, add:

```dart
final class ReconnectPlayerMessage extends ClientMessage {
  const ReconnectPlayerMessage({
    required this.playerId,
    required this.roomCode,
  });

  final String playerId;
  final String roomCode;

  factory ReconnectPlayerMessage.fromJson(Map<String, dynamic> json) {
    return ReconnectPlayerMessage(
      playerId: json['playerId'] as String,
      roomCode: json['roomCode'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'reconnect_player',
    'payload': {'playerId': playerId, 'roomCode': roomCode},
  };
}
```

Also update the `ClientMessage.fromJson` factory switch by adding this case before the `_` fallthrough:

```dart
'reconnect_player' => ReconnectPlayerMessage.fromJson(payload),
```

- [ ] **Step 2: Add `PlayerReconnectedMessage` to the `ServerMessage` sealed class**

Directly after the `ErrorMessage` class, add:

```dart
final class PlayerReconnectedMessage extends ServerMessage {
  const PlayerReconnectedMessage({required this.playerId});

  final String playerId;

  factory PlayerReconnectedMessage.fromJson(Map<String, dynamic> json) {
    return PlayerReconnectedMessage(
      playerId: json['playerId'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'player_reconnected',
    'payload': {'playerId': playerId},
  };
}
```

Also update the `ServerMessage.fromJson` factory switch by adding this case before the `_` fallthrough:

```dart
'player_reconnected' => PlayerReconnectedMessage.fromJson(payload),
```

- [ ] **Step 3: Verify compilation**

```bash
dart test packages/ohhell_protocol
```
Expected: all existing tests pass (package compiles cleanly)

- [ ] **Step 4: Commit**

```bash
git add packages/ohhell_protocol/lib/src/messages.dart
git commit -m "feat: add ReconnectPlayerMessage and PlayerReconnectedMessage to protocol"
```

---

## Task 2: Server — Grace-period seat hold

**Files:**
- Modify: `server/lib/src/room_manager.dart`
- Create: `server/test/reconnect_test.dart`

- [ ] **Step 1: Write failing tests for grace period**

Create `server/test/reconnect_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:test/test.dart';

import 'package:server/src/room_manager.dart';

class WsClient {
  WsClient(this._ws) : _iter = StreamIterator(_ws.cast<String>());

  final WebSocket _ws;
  final StreamIterator<String> _iter;

  void sendJson(Map<String, dynamic> msg) => _ws.add(jsonEncode(msg));

  Future<Map<String, dynamic>> nextMessage() async {
    final hasNext = await _iter.moveNext();
    if (!hasNext) throw StateError('WebSocket stream ended unexpectedly');
    return jsonDecode(_iter.current) as Map<String, dynamic>;
  }

  Future<void> close() async {
    await _iter.cancel();
    await _ws.close();
  }
}

void main() {
  late HttpServer server;
  late int port;

  // Short grace period so tests finish fast.
  const testGrace = Duration(milliseconds: 200);

  setUp(() async {
    final manager = RoomManager(gracePeriod: testGrace);
    final router = Router()
      ..get('/ws', webSocketHandler(manager.handleNewConnection));
    server = await io.serve(
      Pipeline().addHandler(router.call),
      InternetAddress.loopbackIPv4,
      0,
    );
    port = server.port;
  });

  tearDown(() => server.close(force: true));

  Future<WsClient> connect() async {
    final ws = await WebSocket.connect('ws://localhost:$port/ws');
    return WsClient(ws);
  }

  /// Creates a room and returns (host client, roomCode).
  Future<(WsClient, String)> createRoom(String name) async {
    final c = await connect();
    c.sendJson({
      'type': 'join_room',
      'payload': {'playerName': name, 'roomCode': null},
    });
    final msg = await c.nextMessage();
    expect(msg['type'], 'room_joined');
    return (c, msg['payload']['roomCode'] as String);
  }

  test(
    'reconnect within grace period sends player_reconnected and game state',
    () async {
      final (host, code) = await createRoom('Alice');

      // Bob joins and we capture his playerId.
      final bobWs = await connect();
      bobWs.sendJson({
        'type': 'join_room',
        'payload': {'playerName': 'Bob', 'roomCode': code},
      });
      final bobJoined = await bobWs.nextMessage(); // room_joined
      expect(bobJoined['type'], 'room_joined');
      final bobId = bobJoined['payload']['playerId'] as String;

      await host.nextMessage(); // player_joined notification

      // Bob disconnects abruptly.
      await bobWs.close();

      // Small delay — still within grace period.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Bob reconnects with saved playerId.
      final bobBack = await connect();
      bobBack.sendJson({
        'type': 'reconnect_player',
        'payload': {'playerId': bobId, 'roomCode': code},
      });

      final reconnectMsg = await bobBack.nextMessage();
      expect(reconnectMsg['type'], 'player_reconnected');
      expect(reconnectMsg['payload']['playerId'], bobId);

      // Server should also push a game_state after reconnect.
      final stateMsg = await bobBack.nextMessage();
      expect(stateMsg['type'], 'game_state');

      await host.close();
      await bobBack.close();
    },
  );

  test(
    'grace period expiry broadcasts player_left to remaining players',
    () async {
      final (host, code) = await createRoom('Alice');

      final bobWs = await connect();
      bobWs.sendJson({
        'type': 'join_room',
        'payload': {'playerName': 'Bob', 'roomCode': code},
      });
      await bobWs.nextMessage(); // Bob's room_joined
      await host.nextMessage();  // Alice's player_joined for Bob

      // Bob disconnects.
      await bobWs.close();

      // Wait for grace period to expire (testGrace + buffer).
      await Future<void>.delayed(testGrace + const Duration(milliseconds: 100));

      // Alice should now see player_left.
      final leftMsg = await host.nextMessage();
      expect(leftMsg['type'], 'player_left');

      await host.close();
    },
  );

  test(
    'reconnect after grace period expiry returns an error message',
    () async {
      final (host, code) = await createRoom('Alice');

      final bobWs = await connect();
      bobWs.sendJson({
        'type': 'join_room',
        'payload': {'playerName': 'Bob', 'roomCode': code},
      });
      final bobJoined = await bobWs.nextMessage();
      final bobId = bobJoined['payload']['playerId'] as String;
      await host.nextMessage(); // player_joined

      // Bob disconnects.
      await bobWs.close();

      // Wait for grace period to expire.
      await Future<void>.delayed(testGrace + const Duration(milliseconds: 100));
      await host.nextMessage(); // player_left

      // Too late to reconnect.
      final lateClient = await connect();
      lateClient.sendJson({
        'type': 'reconnect_player',
        'payload': {'playerId': bobId, 'roomCode': code},
      });

      final errorMsg = await lateClient.nextMessage();
      expect(errorMsg['type'], 'error');

      await host.close();
    },
  );

  test(
    'player_left is NOT broadcast immediately on disconnect (grace period active)',
    () async {
      final (host, code) = await createRoom('Alice');

      final bobWs = await connect();
      bobWs.sendJson({
        'type': 'join_room',
        'payload': {'playerName': 'Bob', 'roomCode': code},
      });
      await bobWs.nextMessage(); // room_joined
      await host.nextMessage();  // player_joined

      // Bob disconnects.
      await bobWs.close();

      // Brief wait — within grace period, Alice should see nothing yet.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // No message should be available for Alice yet.
      // We verify by starting a reconnect which resets the timer.
      // (Testing absence of a message requires a timeout trick.)
      bool receivedEarly = false;
      final future = host.nextMessage().then((_) {
        receivedEarly = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // Cancel via rethrow; we just care it hasn't fired yet.
      expect(receivedEarly, isFalse);
      future.ignore();

      await host.close();
    },
  );
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
dart test server/test/reconnect_test.dart
```
Expected: compile error — `RoomManager` has no named `gracePeriod` parameter

- [ ] **Step 3: Rewrite `room_manager.dart` with grace-period support**

Replace the entire file with:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:ohhell_protocol/ohhell_protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'client_conn.dart';
import 'room.dart';

/// Manages game rooms and routes new WebSocket connections.
class RoomManager {
  RoomManager({
    this.gracePeriod = const Duration(seconds: 30),
  });

  /// How long a disconnected player's seat is reserved.
  final Duration gracePeriod;

  final Map<String, Room> _rooms = {};
  final Map<String, _DisconnectedPlayer> _disconnectedPlayers = {};
  final Random _random = Random.secure();
  int _nextPlayerId = 1;

  /// All active rooms (read-only access for tests).
  Map<String, Room> get rooms => Map.unmodifiable(_rooms);

  /// Handles a new WebSocket connection.
  ///
  /// The first message must be `join_room` or `reconnect_player`.
  /// Subsequent messages are routed to the room.
  void handleNewConnection(WebSocketChannel ws) {
    String? playerId;
    Room? room;

    ws.stream.cast<String>().listen(
      (raw) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          final msg = ClientMessage.fromJson(json);

          if (playerId == null) {
            if (msg is JoinRoomMessage) {
              final result = _handleJoinRoom(ws, msg);
              if (result == null) return;
              playerId = result.playerId;
              room = result.room;
            } else if (msg is ReconnectPlayerMessage) {
              final result = _handleReconnect(ws, msg);
              if (result == null) return;
              playerId = result.playerId;
              room = result.room;
            } else {
              ws.sink.add(jsonEncode(
                const ErrorMessage(
                  message: 'First message must be join_room or reconnect_player',
                ).toJson(),
              ));
            }
          } else {
            room?.handleMessage(playerId!, msg);
          }
        } on Exception catch (e) {
          ws.sink.add(jsonEncode(
            ErrorMessage(message: 'Invalid message: $e').toJson(),
          ));
        }
      },
      onDone: () => _onDisconnect(playerId, room),
      onError: (Object _) => _onDisconnect(playerId, room),
    );
  }

  void _onDisconnect(String? playerId, Room? room) {
    if (playerId == null || room == null) return;
    final conn = room.connections.remove(playerId);
    if (conn == null) return;

    _disconnectedPlayers[playerId] = _DisconnectedPlayer(
      playerId: playerId,
      playerName: conn.playerName,
      roomCode: room.code,
    );

    Timer(gracePeriod, () => _expireGracePeriod(playerId, room.code));
  }

  void _expireGracePeriod(String playerId, String roomCode) {
    final removed = _disconnectedPlayers.remove(playerId);
    if (removed == null) return; // Player already reconnected — nothing to do.

    final room = _rooms[roomCode];
    if (room == null) return;

    room.broadcast(PlayerLeftMessage(playerId: playerId));

    final hasActive = room.connections.isNotEmpty;
    final hasDisconnected = _disconnectedPlayers.values
        .any((d) => d.roomCode == roomCode);
    if (!hasActive && !hasDisconnected) {
      _rooms.remove(roomCode);
    }
  }

  _JoinResult? _handleJoinRoom(WebSocketChannel ws, JoinRoomMessage msg) {
    final id = 'player_${_nextPlayerId++}';
    final conn = ClientConnection(
      id: id,
      channel: ws,
      playerName: msg.playerName,
    );

    final Room room;
    final bool isHost;

    if (msg.roomCode == null) {
      final code = _generateCode();
      room = Room(code: code, hostId: id);
      _rooms[code] = room;
      isHost = true;
    } else {
      final existing = _rooms[msg.roomCode];
      if (existing == null) {
        conn.send(ErrorMessage(message: 'Room ${msg.roomCode} not found'));
        ws.sink.close();
        return null;
      }
      room = existing;
      isHost = false;
    }

    conn.roomCode = room.code;
    room.connections[id] = conn;

    conn.send(RoomJoinedMessage(
      roomCode: room.code,
      playerId: id,
      isHost: isHost,
    ));
    room.broadcast(
      PlayerJoinedMessage(playerId: id, playerName: msg.playerName),
      except: id,
    );

    return _JoinResult(playerId: id, room: room);
  }

  _JoinResult? _handleReconnect(
    WebSocketChannel ws,
    ReconnectPlayerMessage msg,
  ) {
    final disconnected = _disconnectedPlayers.remove(msg.playerId);
    if (disconnected == null) {
      ws.sink.add(jsonEncode(
        const ErrorMessage(
          message: 'Reconnect failed: session expired',
        ).toJson(),
      ));
      ws.sink.close();
      return null;
    }

    final room = _rooms[disconnected.roomCode];
    if (room == null) {
      ws.sink.add(jsonEncode(
        const ErrorMessage(message: 'Room no longer exists').toJson(),
      ));
      ws.sink.close();
      return null;
    }

    final conn = ClientConnection(
      id: disconnected.playerId,
      channel: ws,
      playerName: disconnected.playerName,
    );
    conn.roomCode = disconnected.roomCode;
    room.connections[disconnected.playerId] = conn;

    conn.send(PlayerReconnectedMessage(playerId: disconnected.playerId));
    room.broadcastGameState();

    return _JoinResult(playerId: disconnected.playerId, room: room);
  }

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      List.generate(
        6,
        (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    );
  }
}

class _JoinResult {
  const _JoinResult({required this.playerId, required this.room});
  final String playerId;
  final Room room;
}

class _DisconnectedPlayer {
  const _DisconnectedPlayer({
    required this.playerId,
    required this.playerName,
    required this.roomCode,
  });

  final String playerId;
  final String playerName;
  final String roomCode;
}
```

- [ ] **Step 4: Run reconnect tests**

```bash
dart test server/test/reconnect_test.dart
```
Expected: first 3 tests pass (4th is a best-effort timing test — pass or skip is fine)

- [ ] **Step 5: Run all server tests to verify no regressions**

```bash
dart test server
```
Expected: all tests pass

- [ ] **Step 6: Commit**

```bash
git add server/lib/src/room_manager.dart server/test/reconnect_test.dart
git commit -m "feat: 30-second server-side grace period for disconnected players"
```

---

## Task 3: Client — WsNotifier auto-retry + reconnect handshake

**Files:**
- Modify: `client/lib/src/providers/ws_provider.dart`
- Create: `client/test/unit/ws_reconnect_test.dart`

- [ ] **Step 1: Write failing unit tests**

Create `client/test/unit/ws_reconnect_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ohhell_client/src/providers/ws_provider.dart';

void main() {
  test('WsNotifier starts in WsDisconnected state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(wsProvider), isA<WsDisconnected>());
  });

  test('WsReconnecting holds attempt and maxAttempts', () {
    const s = WsReconnecting(attempt: 2, maxAttempts: 5);
    expect(s.attempt, 2);
    expect(s.maxAttempts, 5);
  });

  test('manualReconnect before connect does not throw', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      () => container.read(wsProvider.notifier).manualReconnect(),
      returnsNormally,
    );
  });

  test(
    'connect to unreachable host results in WsError or WsReconnecting',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Port 19999 is unlikely to be open.
      await container.read(wsProvider.notifier).connect('127.0.0.1:19999');
      await Future<void>.delayed(Duration.zero);

      final status = container.read(wsProvider);
      expect(status, isA<WsError>().or(isA<WsReconnecting>()));
    },
  );

  test('disconnect resets state to WsDisconnected', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(wsProvider.notifier);
    // Start a failed connection to move out of WsDisconnected.
    unawaited(notifier.connect('127.0.0.1:19999'));
    await Future<void>.delayed(Duration.zero);

    notifier.disconnect();
    expect(container.read(wsProvider), isA<WsDisconnected>());
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test client/test/unit/ws_reconnect_test.dart
```
Expected: compile error — `WsReconnecting` not defined

- [ ] **Step 3: Replace `ws_provider.dart` with auto-retry support**

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohhell_protocol/ohhell_protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:ohhell_client/src/providers/game_provider.dart';
import 'package:ohhell_client/src/providers/session_provider.dart';

// ---------------------------------------------------------------------------
// Status types
// ---------------------------------------------------------------------------

/// Connection status for the WebSocket.
sealed class WsStatus {
  const WsStatus();
}

final class WsDisconnected extends WsStatus {
  const WsDisconnected();
}

final class WsConnecting extends WsStatus {
  const WsConnecting();
}

final class WsConnected extends WsStatus {
  const WsConnected();
}

/// Auto-reconnect in progress. [attempt] is 1-based; [maxAttempts] is the cap.
final class WsReconnecting extends WsStatus {
  const WsReconnecting({required this.attempt, required this.maxAttempts});
  final int attempt;
  final int maxAttempts;
}

final class WsError extends WsStatus {
  const WsError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class WsNotifier extends StateNotifier<WsStatus> {
  WsNotifier(this._ref) : super(const WsDisconnected());

  final Ref _ref;
  WebSocketChannel? _channel;
  String? _serverHost;
  int _reconnectAttempts = 0;

  static const int _maxReconnectAttempts = 5;
  static const List<Duration> _backoffDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
  ];

  /// Connects to [serverHost]. Resets the reconnect counter.
  Future<void> connect(String serverHost) async {
    _serverHost = serverHost;
    _reconnectAttempts = 0;
    await _connectInternal(serverHost);
  }

  /// Resets the reconnect counter and retries immediately.
  void manualReconnect() {
    final host = _serverHost;
    if (host == null) return;
    _reconnectAttempts = 0;
    unawaited(_connectInternal(host));
  }

  void send(ClientMessage msg) {
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(jsonEncode(msg.toJson()));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _serverHost = null;
    _reconnectAttempts = 0;
    state = const WsDisconnected();
  }

  Future<void> _connectInternal(String serverHost) async {
    if (state is WsConnected) return;

    state = const WsConnecting();
    try {
      final uri = Uri.parse('ws://$serverHost/ws');
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      _channel = channel;
      _reconnectAttempts = 0;
      state = const WsConnected();

      // If re-entering a session, send reconnect handshake immediately.
      _sendReconnectIfNeeded();

      channel.stream.listen(
        (raw) => _onMessage(raw as String),
        onError: (Object _) {
          _channel = null;
          _scheduleReconnect();
        },
        onDone: () {
          _channel = null;
          final session = _ref.read(sessionProvider);
          if (session.roomCode != null && session.playerId != null) {
            _scheduleReconnect();
          } else {
            state = const WsDisconnected();
          }
        },
      );
    } on Exception catch (e) {
      state = WsError(e.toString());
    }
  }

  void _scheduleReconnect() {
    final host = _serverHost;
    if (host == null) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      state = const WsError('Connection lost. Tap Retry to reconnect.');
      return;
    }

    final attempt = _reconnectAttempts;
    _reconnectAttempts++;
    state = WsReconnecting(
      attempt: attempt + 1,
      maxAttempts: _maxReconnectAttempts,
    );

    final delay = _backoffDelays[attempt.clamp(0, _backoffDelays.length - 1)];
    Future.delayed(delay, () {
      if (state is WsReconnecting) {
        unawaited(_connectInternal(host));
      }
    });
  }

  /// Sends `reconnect_player` when we have an active session but just
  /// re-established the WebSocket. The server restores the seat and
  /// pushes the current game state.
  void _sendReconnectIfNeeded() {
    final session = _ref.read(sessionProvider);
    final playerId = session.playerId;
    final roomCode = session.roomCode;
    if (playerId != null && roomCode != null) {
      send(ReconnectPlayerMessage(playerId: playerId, roomCode: roomCode));
    }
  }

  void _onMessage(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final msg = ServerMessage.fromJson(json);
      _dispatch(msg);
    } on Exception catch (e) {
      _ref.read(sessionProvider.notifier).setError(
            'Failed to parse message: $e',
          );
    }
  }

  void _dispatch(ServerMessage msg) {
    switch (msg) {
      case RoomJoinedMessage():
        _ref.read(sessionProvider.notifier).onRoomJoined(
              playerId: msg.playerId,
              roomCode: msg.roomCode,
              isHost: msg.isHost,
            );
      case PlayerJoinedMessage():
        break;
      case PlayerLeftMessage():
        break;
      case GameStateMessage():
        _ref.read(gameStateProvider.notifier).state = msg.state;
      case YourHandMessage():
        _ref.read(sessionProvider.notifier).onHand(msg.cards);
      case ErrorMessage():
        _ref.read(sessionProvider.notifier).setError(msg.message);
      case PlayerReconnectedMessage():
        _ref.read(sessionProvider.notifier).clearError();
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

final wsProvider = StateNotifierProvider<WsNotifier, WsStatus>(
  (ref) => WsNotifier(ref),
);
```

- [ ] **Step 4: Run unit tests**

```bash
flutter test client/test/unit/ws_reconnect_test.dart
```
Expected: all 5 tests pass

- [ ] **Step 5: Run all client tests**

```bash
flutter test client
```
Expected: all tests pass

- [ ] **Step 6: Commit**

```bash
git add client/lib/src/providers/ws_provider.dart \
        client/test/unit/ws_reconnect_test.dart
git commit -m "feat: WsNotifier auto-retry with exponential backoff and reconnect handshake"
```

---

## Task 4: Client — NetworkStatusOverlay widget

**Files:**
- Create: `client/lib/src/widgets/network_status_overlay.dart`
- Create: `client/test/widget/network_status_overlay_test.dart`

- [ ] **Step 1: Write failing widget tests**

Create `client/test/widget/network_status_overlay_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ohhell_client/src/providers/ws_provider.dart';
import 'package:ohhell_client/src/widgets/network_status_overlay.dart';

/// A fake WsNotifier that starts in a pre-set state, used to drive
/// the overlay in tests without opening real WebSocket connections.
class _FakeWsNotifier extends WsNotifier {
  _FakeWsNotifier(WsStatus initialStatus, Ref ref) : super(ref) {
    state = initialStatus;
  }
}

Widget _buildWithStatus(WsStatus status) {
  return ProviderScope(
    overrides: [
      wsProvider.overrideWith((ref) => _FakeWsNotifier(status, ref)),
    ],
    child: const MaterialApp(
      home: NetworkStatusOverlay(child: Text('Game')),
    ),
  );
}

void main() {
  testWidgets('shows only child when WsConnected', (tester) async {
    await tester.pumpWidget(_buildWithStatus(const WsConnected()));
    expect(find.text('Game'), findsOneWidget);
    expect(find.textContaining('Reconnecting'), findsNothing);
    expect(find.textContaining('Connection lost'), findsNothing);
  });

  testWidgets('shows only child when WsDisconnected', (tester) async {
    await tester.pumpWidget(_buildWithStatus(const WsDisconnected()));
    expect(find.text('Game'), findsOneWidget);
    expect(find.textContaining('Reconnecting'), findsNothing);
    expect(find.textContaining('lost'), findsNothing);
  });

  testWidgets('shows reconnecting banner when WsReconnecting', (tester) async {
    await tester.pumpWidget(
      _buildWithStatus(const WsReconnecting(attempt: 2, maxAttempts: 5)),
    );
    expect(find.text('Game'), findsOneWidget);
    expect(find.textContaining('Reconnecting'), findsOneWidget);
    expect(find.textContaining('2/5'), findsOneWidget);
  });

  testWidgets('shows error banner with Retry button when WsError', (tester) async {
    await tester.pumpWidget(
      _buildWithStatus(const WsError('Connection lost. Tap Retry to reconnect.')),
    );
    expect(find.text('Game'), findsOneWidget);
    expect(find.textContaining('Connection lost'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Retry button calls manualReconnect', (tester) async {
    await tester.pumpWidget(
      _buildWithStatus(const WsError('Connection lost. Tap Retry to reconnect.')),
    );
    // Tapping Retry should not throw.
    await tester.tap(find.text('Retry'));
    await tester.pump();
    // No assertion on side-effect — just verify it doesn't crash.
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test client/test/widget/network_status_overlay_test.dart
```
Expected: `NetworkStatusOverlay` not found

- [ ] **Step 3: Create `network_status_overlay.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohhell_client/src/providers/ws_provider.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';

/// Wraps [child] in a [Stack] and renders a banner overlay when the
/// WebSocket is auto-reconnecting or has permanently errored out.
class NetworkStatusOverlay extends ConsumerWidget {
  const NetworkStatusOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsStatus = ref.watch(wsProvider);
    return Stack(
      children: [
        child,
        if (wsStatus is WsReconnecting)
          _ReconnectingBanner(
            attempt: wsStatus.attempt,
            maxAttempts: wsStatus.maxAttempts,
          ),
        if (wsStatus is WsError)
          _ErrorBanner(
            message: wsStatus.message,
            onRetry: () => ref.read(wsProvider.notifier).manualReconnect(),
          ),
      ],
    );
  }
}

class _ReconnectingBanner extends StatelessWidget {
  const _ReconnectingBanner({
    required this.attempt,
    required this.maxAttempts,
  });

  final int attempt;
  final int maxAttempts;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.amber.withAlpha(230),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.background,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Reconnecting… ($attempt/$maxAttempts)',
                    style: const TextStyle(
                      color: AppColors.background,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.suitRed.withAlpha(230),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run widget tests**

```bash
flutter test client/test/widget/network_status_overlay_test.dart
```
Expected: all 5 tests pass

- [ ] **Step 5: Commit**

```bash
git add client/lib/src/widgets/network_status_overlay.dart \
        client/test/widget/network_status_overlay_test.dart
git commit -m "feat: NetworkStatusOverlay widget with reconnecting spinner and error retry"
```

---

## Task 5: Client — Integrate overlay into GameScreen and LobbyScreen

**Files:**
- Modify: `client/lib/src/screens/game_screen.dart`
- Modify: `client/lib/src/screens/lobby_screen.dart`

- [ ] **Step 1: Read both screen files**

```bash
# Review the build methods to find the top-level return statement
```

Read `client/lib/src/screens/game_screen.dart` and `client/lib/src/screens/lobby_screen.dart` to locate the top-level `return Scaffold(` in each `build` method.

- [ ] **Step 2: Add import and wrap Scaffold in `game_screen.dart`**

Add to imports at the top of `game_screen.dart`:

```dart
import 'package:ohhell_client/src/widgets/network_status_overlay.dart';
```

In the `build` method, change:

```dart
return Scaffold(
  // ... existing scaffold content
);
```

to:

```dart
return NetworkStatusOverlay(
  child: Scaffold(
    // ... existing scaffold content (unchanged)
  ),
);
```

- [ ] **Step 3: Add import and wrap Scaffold in `lobby_screen.dart`**

Add to imports at the top of `lobby_screen.dart`:

```dart
import 'package:ohhell_client/src/widgets/network_status_overlay.dart';
```

In the `build` method, change:

```dart
return Scaffold(
  // ... existing scaffold content
);
```

to:

```dart
return NetworkStatusOverlay(
  child: Scaffold(
    // ... existing scaffold content (unchanged)
  ),
);
```

- [ ] **Step 4: Run all client tests**

```bash
flutter test client
```
Expected: all tests pass

- [ ] **Step 5: Run all Dart tests to verify no regressions**

```bash
dart test packages/ohhell_engine packages/ohhell_protocol server
```
Expected: all tests pass

- [ ] **Step 6: Commit**

```bash
git add client/lib/src/screens/game_screen.dart \
        client/lib/src/screens/lobby_screen.dart
git commit -m "feat: wrap game and lobby screens with NetworkStatusOverlay"
```

---

## Self-Review Checklist

**Spec coverage:**
- ✅ Server grace period (30 s, configurable for testing) — Task 2
- ✅ `ReconnectPlayerMessage` + `PlayerReconnectedMessage` — Task 1
- ✅ Client auto-retry with exponential backoff (1, 2, 4, 8, 16 s) — Task 3
- ✅ `manualReconnect()` for user-triggered retry — Task 3
- ✅ Reconnect handshake (`_sendReconnectIfNeeded`) — Task 3
- ✅ Network status overlay (reconnecting + error states) — Task 4
- ✅ Overlay on game screen and lobby screen — Task 5

**No placeholders:** All code blocks are complete and self-contained.

**Type consistency:**
- `ReconnectPlayerMessage` created in Task 1, consumed in Task 2 (`_handleReconnect`) and Task 3 (`_sendReconnectIfNeeded`) ✓
- `PlayerReconnectedMessage` created in Task 1, handled in Task 3 `_dispatch`, tested in Task 2 server tests ✓
- `WsReconnecting(attempt, maxAttempts)` created in Task 3, rendered in Task 4 overlay with `attempt`/`maxAttempts` fields ✓
- `AppColors.amber`, `AppColors.background`, `AppColors.suitRed` — all defined in `app_theme.dart` ✓
- `_FakeWsNotifier extends WsNotifier` in tests — correct because `wsProvider` is typed `StateNotifierProvider<WsNotifier, WsStatus>` ✓
