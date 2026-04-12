import 'package:ohhell_engine/ohhell_engine.dart';
import 'package:ohhell_protocol/ohhell_protocol.dart';

import 'client_conn.dart';

/// A game room holding connected players and game state.
class Room {
  Room({required this.code, required this.hostId})
      : _state = GameState(
          phase: const Lobby(),
          players: const [],
          config: GameConfig.defaultFor(3),
        );

  final String code;
  final String hostId;
  final Map<String, ClientConnection> connections = {};
  final GameEngine _engine = const GameEngine();

  GameState _state;

  /// Current game state (read-only access for tests).
  GameState get state => _state;

  /// Broadcasts a [ServerMessage] to all connected clients,
  /// optionally excluding one player.
  void broadcast(ServerMessage msg, {String? except}) {
    for (final entry in connections.entries) {
      if (entry.key != except) {
        entry.value.send(msg);
      }
    }
  }

  /// Broadcasts the current game state to all players.
  ///
  /// Sends `game_state` (without hands) to everyone, and
  /// `your_hand` privately to each player.
  void broadcastGameState() {
    final dto = GameStateDto.fromGameState(_state);
    final gameMsg = GameStateMessage(state: dto);
    broadcast(gameMsg);

    for (final player in _state.players) {
      final conn = connections[player.id];
      if (conn != null) {
        final handMsg = YourHandMessage(
          cards: player.hand.map(CardDto.fromCard).toList(),
        );
        conn.send(handMsg);
      }
    }
  }

  /// Handles a message from a connected player.
  void handleMessage(String playerId, ClientMessage msg) {
    switch (msg) {
      case JoinRoomMessage():
        // Handled by RoomManager before reaching here.
        return;
      case StartGameMessage():
        _handleStartGame(playerId);
      case PlaceBidMessage():
        _handlePlaceBid(playerId, msg.bid);
      case PlayCardMessage():
        _handlePlayCard(playerId, msg.suit, msg.rank);
      case LeaveRoomMessage():
        _handleLeaveRoom(playerId);
    }
  }

  void _handleStartGame(String playerId) {
    if (playerId != hostId) {
      connections[playerId]?.send(
        const ErrorMessage(message: 'Only the host can start the game'),
      );
      return;
    }

    if (_state.phase is! Lobby) {
      connections[playerId]?.send(
        const ErrorMessage(message: 'Game already started'),
      );
      return;
    }

    final playerCount = connections.length;
    if (playerCount < 3) {
      connections[playerId]?.send(
        const ErrorMessage(message: 'Need at least 3 players to start'),
      );
      return;
    }

    try {
      final players = connections.values
          .map((c) => Player(id: c.id, name: c.playerName))
          .toList();
      final config = GameConfig.defaultFor(playerCount);
      _state = _engine.startGame(players, config);
      _state = _engine.dealRound(_state);
      broadcastGameState();
    } on Exception catch (e) {
      connections[playerId]?.send(
        ErrorMessage(message: e.toString()),
      );
    }
  }

  void _handlePlaceBid(String playerId, int bid) {
    try {
      _state = _engine.placeBid(_state, playerId, bid);
      broadcastGameState();
    } on Exception catch (e) {
      connections[playerId]?.send(
        ErrorMessage(message: e.toString()),
      );
    }
  }

  void _handlePlayCard(String playerId, String suitName, String rankName) {
    try {
      final suit = Suit.values.firstWhere((s) => s.name == suitName);
      final rank = Rank.values.firstWhere((r) => r.name == rankName);
      final card = PlayingCard(suit: suit, rank: rank);
      _state = _engine.playCard(_state, playerId, card);
      broadcastGameState();
    } on Exception catch (e) {
      connections[playerId]?.send(
        ErrorMessage(message: e.toString()),
      );
    }
  }

  void _handleLeaveRoom(String playerId) {
    final conn = connections.remove(playerId);
    conn?.channel.sink.close();
    broadcast(PlayerLeftMessage(playerId: playerId));
  }
}
