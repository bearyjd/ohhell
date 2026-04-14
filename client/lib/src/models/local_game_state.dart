import 'package:ohhell_engine/ohhell_engine.dart';

/// Phases of a local (offline) game as seen by the client.
enum LocalGamePhase { idle, dealing, bidding, playing, roundEnd, gameOver }

/// Immutable client-side state for a local bot game.
class LocalGameState {
  const LocalGameState({
    required this.phase,
    required this.gameState,
    required this.humanPlayerId,
    required this.botPlayerIds,
    required this.awaitingBot,
  });

  const LocalGameState.idle()
      : phase = LocalGamePhase.idle,
        gameState = null,
        humanPlayerId = null,
        botPlayerIds = const [],
        awaitingBot = false;

  final LocalGamePhase phase;
  final GameState? gameState;
  final String? humanPlayerId;
  final List<String> botPlayerIds;
  final bool awaitingBot;

  LocalGameState copyWith({
    LocalGamePhase? phase,
    GameState? gameState,
    String? humanPlayerId,
    List<String>? botPlayerIds,
    bool? awaitingBot,
  }) =>
      LocalGameState(
        phase: phase ?? this.phase,
        gameState: gameState ?? this.gameState,
        humanPlayerId: humanPlayerId ?? this.humanPlayerId,
        botPlayerIds: botPlayerIds ?? this.botPlayerIds,
        awaitingBot: awaitingBot ?? this.awaitingBot,
      );
}
