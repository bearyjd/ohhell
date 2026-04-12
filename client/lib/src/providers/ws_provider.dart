import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohhell_protocol/ohhell_protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:ohhell_client/src/providers/game_provider.dart';
import 'package:ohhell_client/src/providers/session_provider.dart';

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

final class WsError extends WsStatus {
  const WsError(this.message);
  final String message;
}

class WsNotifier extends StateNotifier<WsStatus> {
  WsNotifier(this._ref) : super(const WsDisconnected());

  final Ref _ref;
  WebSocketChannel? _channel;

  Future<void> connect(String serverHost) async {
    if (state is WsConnecting || state is WsConnected) return;

    state = const WsConnecting();
    try {
      final uri = Uri.parse('ws://$serverHost/ws');
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      _channel = channel;
      state = const WsConnected();

      channel.stream.listen(
        (raw) => _onMessage(raw as String),
        onError: (Object error) {
          state = WsError(error.toString());
        },
        onDone: () {
          _channel = null;
          state = const WsDisconnected();
        },
      );
    } on Exception catch (e) {
      state = WsError(e.toString());
    }
  }

  void send(ClientMessage msg) {
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(jsonEncode(msg.toJson()));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    state = const WsDisconnected();
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
        // Game state will be updated via GameStateMessage
        break;
      case PlayerLeftMessage():
        // Game state will be updated via GameStateMessage
        break;
      case GameStateMessage():
        _ref.read(gameStateProvider.notifier).state = msg.state;
      case YourHandMessage():
        _ref.read(sessionProvider.notifier).onHand(msg.cards);
      case ErrorMessage():
        _ref.read(sessionProvider.notifier).setError(msg.message);
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
