import 'card.dart';
import 'game_config.dart';

/// Phase of the game.
sealed class GamePhase {
  const GamePhase();
}

final class Lobby extends GamePhase {
  const Lobby();
}

final class Dealing extends GamePhase {
  const Dealing();
}

final class Bidding extends GamePhase {
  const Bidding();
}

final class Playing extends GamePhase {
  const Playing();
}

final class RoundEnd extends GamePhase {
  const RoundEnd();
}

final class GameEnd extends GamePhase {
  const GameEnd();
}

/// A single play within a trick.
class TrickPlay {
  const TrickPlay({required this.playerId, required this.card});

  final String playerId;
  final PlayingCard card;

  TrickPlay copyWith({String? playerId, PlayingCard? card}) {
    return TrickPlay(
      playerId: playerId ?? this.playerId,
      card: card ?? this.card,
    );
  }
}

/// A trick consisting of plays from each player.
class Trick {
  const Trick({this.plays = const [], this.leadSuit, this.trumpSuit});

  final List<TrickPlay> plays;
  final Suit? leadSuit;
  final Suit? trumpSuit;

  Trick copyWith({
    List<TrickPlay>? plays,
    Suit? Function()? leadSuit,
    Suit? Function()? trumpSuit,
  }) {
    return Trick(
      plays: plays ?? this.plays,
      leadSuit: leadSuit != null ? leadSuit() : this.leadSuit,
      trumpSuit: trumpSuit != null ? trumpSuit() : this.trumpSuit,
    );
  }
}

/// An immutable player.
class Player {
  const Player({
    required this.id,
    required this.name,
    this.hand = const [],
    this.bid,
    this.tricksWon = 0,
    this.totalScore = 0,
  });

  final String id;
  final String name;
  final List<PlayingCard> hand;
  final int? bid;
  final int tricksWon;
  final int totalScore;

  Player copyWith({
    String? id,
    String? name,
    List<PlayingCard>? hand,
    int? Function()? bid,
    int? tricksWon,
    int? totalScore,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      hand: hand ?? this.hand,
      bid: bid != null ? bid() : this.bid,
      tricksWon: tricksWon ?? this.tricksWon,
      totalScore: totalScore ?? this.totalScore,
    );
  }
}

/// State of a single round.
class RoundState {
  const RoundState({
    required this.roundNumber,
    required this.cardsPerHand,
    this.trumpSuit,
    this.bids = const {},
    this.tricks = const [],
    this.currentTrick = const Trick(),
    this.currentPlayerIndex = 0,
  });

  final int roundNumber;
  final int cardsPerHand;
  final Suit? trumpSuit;
  final Map<String, int> bids;
  final List<Trick> tricks;
  final Trick currentTrick;
  final int currentPlayerIndex;

  RoundState copyWith({
    int? roundNumber,
    int? cardsPerHand,
    Suit? Function()? trumpSuit,
    Map<String, int>? bids,
    List<Trick>? tricks,
    Trick? currentTrick,
    int? currentPlayerIndex,
  }) {
    return RoundState(
      roundNumber: roundNumber ?? this.roundNumber,
      cardsPerHand: cardsPerHand ?? this.cardsPerHand,
      trumpSuit: trumpSuit != null ? trumpSuit() : this.trumpSuit,
      bids: bids ?? this.bids,
      tricks: tricks ?? this.tricks,
      currentTrick: currentTrick ?? this.currentTrick,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
    );
  }
}

/// The complete game state.
class GameState {
  const GameState({
    required this.phase,
    required this.players,
    required this.config,
    this.rounds = const [],
    this.currentRound,
    this.winnerId,
  });

  final GamePhase phase;
  final List<Player> players;
  final List<RoundState> rounds;
  final RoundState? currentRound;
  final GameConfig config;
  final String? winnerId;

  GameState copyWith({
    GamePhase? phase,
    List<Player>? players,
    List<RoundState>? rounds,
    RoundState? Function()? currentRound,
    GameConfig? config,
    String? Function()? winnerId,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      players: players ?? this.players,
      rounds: rounds ?? this.rounds,
      currentRound: currentRound != null ? currentRound() : this.currentRound,
      config: config ?? this.config,
      winnerId: winnerId != null ? winnerId() : this.winnerId,
    );
  }
}
