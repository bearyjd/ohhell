import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohhell_protocol/ohhell_protocol.dart';

/// Local player session state.
class SessionState {
  const SessionState({
    this.serverHost = 'localhost:8080',
    this.playerName = '',
    this.playerId,
    this.roomCode,
    this.isHost = false,
    this.hand = const [],
    this.error,
  });

  final String serverHost;
  final String playerName;
  final String? playerId;
  final String? roomCode;
  final bool isHost;
  final List<CardDto> hand;
  final String? error;

  SessionState copyWith({
    String? serverHost,
    String? playerName,
    String? playerId,
    String? roomCode,
    bool? isHost,
    List<CardDto>? hand,
    String? error,
    bool clearError = false,
    bool clearPlayerId = false,
    bool clearRoomCode = false,
  }) {
    return SessionState(
      serverHost: serverHost ?? this.serverHost,
      playerName: playerName ?? this.playerName,
      playerId: clearPlayerId ? null : (playerId ?? this.playerId),
      roomCode: clearRoomCode ? null : (roomCode ?? this.roomCode),
      isHost: isHost ?? this.isHost,
      hand: hand ?? this.hand,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(const SessionState());

  void setServerHost(String host) {
    state = state.copyWith(serverHost: host);
  }

  void setPlayerName(String name) {
    state = state.copyWith(playerName: name);
  }

  void onRoomJoined({
    required String playerId,
    required String roomCode,
    required bool isHost,
  }) {
    state = state.copyWith(
      playerId: playerId,
      roomCode: roomCode,
      isHost: isHost,
      clearError: true,
    );
  }

  void onHand(List<CardDto> cards) {
    state = state.copyWith(hand: cards);
  }

  void setError(String message) {
    state = state.copyWith(error: message);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void reset() {
    state = SessionState(
      serverHost: state.serverHost,
      playerName: state.playerName,
    );
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>(
  (ref) => SessionNotifier(),
);
