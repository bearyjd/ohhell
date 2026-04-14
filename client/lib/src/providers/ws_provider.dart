import 'dart:async';
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

final class WsReconnecting extends WsStatus {
  const WsReconnecting({required this.attempt, required this.maxAttempts});
  final int attempt;
  final int maxAttempts;
}

final class WsError extends WsStatus {
  const WsError(this.message);
  final String message;
}

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

  Future<void> connect(String serverHost) async {
    _serverHost = serverHost;
    _reconnectAttempts = 0;
    await _connectInternal(serverHost);
  }

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
      _sendReconnectIfNeeded();
      channel.stream.listen(
        (raw) => _onMessage(raw as String),
        onError: (Object _) {
          _channel = null;
          _scheduleReconnect();
        },
        onDone: () {
          _channel = null;
          _scheduleReconnect();
        },
      );
    } on Exception catch (_) {
      _scheduleReconnect();
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
