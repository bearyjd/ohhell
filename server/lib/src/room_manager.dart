import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:ohhell_protocol/ohhell_protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'client_conn.dart';
import 'room.dart';

/// Manages game rooms and routes new WebSocket connections.
///
/// Disconnected players are held in a grace period before being
/// permanently removed, allowing them to reconnect seamlessly.
class RoomManager {
  RoomManager({
    this.gracePeriod = const Duration(seconds: 30),
  });

  final Duration gracePeriod;
  final Map<String, Room> _rooms = {};
  final Map<String, _DisconnectedPlayer> _disconnectedPlayers = {};
  final Random _random = Random.secure();
  int _nextPlayerId = 1;

  /// All active rooms (read-only access for tests).
  Map<String, Room> get rooms => Map.unmodifiable(_rooms);

  /// Handles a new WebSocket connection.
  ///
  /// Listens on the stream once. The first message must be either
  /// `join_room` or `reconnect_player`; subsequent messages are
  /// routed to the room.
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
                  message:
                      'First message must be join_room or reconnect_player',
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
    if (removed == null) return; // already reconnected

    final room = _rooms[roomCode];
    if (room == null) return;

    room.broadcast(PlayerLeftMessage(playerId: playerId));

    final hasActive = room.connections.isNotEmpty;
    final hasDisconnected =
        _disconnectedPlayers.values.any((d) => d.roomCode == roomCode);
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

    final room = _rooms[msg.roomCode];
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
      List.generate(6, (_) => chars.codeUnitAt(_random.nextInt(chars.length))),
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
