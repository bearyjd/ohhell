import 'dart:convert';
import 'dart:math';

import 'package:ohhell_protocol/ohhell_protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'client_conn.dart';
import 'room.dart';

/// Manages game rooms and routes new WebSocket connections.
class RoomManager {
  final Map<String, Room> _rooms = {};
  final Random _random = Random.secure();
  int _nextPlayerId = 1;

  /// All active rooms (read-only access for tests).
  Map<String, Room> get rooms => Map.unmodifiable(_rooms);

  /// Handles a new WebSocket connection.
  ///
  /// Listens on the stream once. The first message must be
  /// `join_room`; subsequent messages are routed to the room.
  void handleNewConnection(WebSocketChannel ws) {
    String? playerId;
    Room? room;

    ws.stream.cast<String>().listen(
      (raw) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          final msg = ClientMessage.fromJson(json);

          if (playerId == null) {
            // First message must be join_room
            if (msg is! JoinRoomMessage) {
              ws.sink.add(jsonEncode(
                const ErrorMessage(
                  message: 'First message must be join_room',
                ).toJson(),
              ));
              return;
            }
            final result = _handleJoinRoom(ws, msg);
            if (result == null) return;
            playerId = result.playerId;
            room = result.room;
          } else {
            room?.handleMessage(playerId!, msg);
          }
        } on Exception catch (e) {
          ws.sink.add(jsonEncode(
            ErrorMessage(message: 'Invalid message: $e').toJson(),
          ));
        }
      },
      onDone: () {
        if (playerId != null && room != null) {
          room!.connections.remove(playerId);
          room!.broadcast(PlayerLeftMessage(playerId: playerId!));
          if (room!.connections.isEmpty) {
            _rooms.remove(room!.code);
          }
        }
      },
      onError: (Object error) {
        if (playerId != null && room != null) {
          room!.connections.remove(playerId);
          room!.broadcast(PlayerLeftMessage(playerId: playerId!));
          if (room!.connections.isEmpty) {
            _rooms.remove(room!.code);
          }
        }
      },
    );
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
      // Create a new room
      final code = _generateCode();
      room = Room(code: code, hostId: id);
      _rooms[code] = room;
      isHost = true;
    } else {
      // Join existing room
      final existing = _rooms[msg.roomCode];
      if (existing == null) {
        conn.send(ErrorMessage(
          message: 'Room ${msg.roomCode} not found',
        ));
        ws.sink.close();
        return null;
      }
      room = existing;
      isHost = false;
    }

    conn.roomCode = room.code;
    room.connections[id] = conn;

    // Notify the joining player
    conn.send(RoomJoinedMessage(
      roomCode: room.code,
      playerId: id,
      isHost: isHost,
    ));

    // Notify others in the room
    room.broadcast(
      PlayerJoinedMessage(playerId: id, playerName: msg.playerName),
      except: id,
    );

    return _JoinResult(playerId: id, room: room);
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
