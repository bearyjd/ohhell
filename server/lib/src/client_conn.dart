import 'dart:convert';

import 'package:ohhell_protocol/ohhell_protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Wraps a WebSocket connection for a single client.
class ClientConnection {
  ClientConnection({
    required this.id,
    required this.channel,
    required this.playerName,
  });

  /// Server-assigned player ID.
  final String id;

  /// The underlying WebSocket channel.
  final WebSocketChannel channel;

  /// Display name chosen by the player.
  final String playerName;

  /// Room code this player belongs to (set after joining).
  String? roomCode;

  /// Sends a [ServerMessage] to this client.
  void send(ServerMessage msg) {
    channel.sink.add(jsonEncode(msg.toJson()));
  }

  /// Parses a raw JSON string into a [ClientMessage].
  static ClientMessage parseMessage(String raw) {
    return ClientMessage.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }
}
