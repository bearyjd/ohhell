/// Scoring variant for the game.
enum ScoringVariant {
  /// Exact bid: +10 + bid. Wrong: +tricksWon.
  standard,

  /// Exact bid: +10 + bid. Wrong: -tricksWon.
  strict,
}

/// Configuration for a game of Oh Hell.
class GameConfig {
  const GameConfig({
    required this.roundSchedule,
    this.scoringVariant = ScoringVariant.standard,
  });

  /// Cards dealt per round.
  final List<int> roundSchedule;

  /// Scoring variant used.
  final ScoringVariant scoringVariant;

  /// Computes the default Oh Hell schedule for a given player count.
  ///
  /// Goes up from 1 to max cards, then back down to 1.
  /// Max cards = 52 ~/ playerCount (leaving at least 1 for trump).
  static GameConfig defaultFor(int playerCount) {
    if (playerCount < 3 || playerCount > 7) {
      throw ArgumentError('Player count must be 3-7, got $playerCount');
    }
    // Need at least 1 card remaining for trump after dealing
    final maxCards = (52 - 1) ~/ playerCount;
    final schedule = <int>[
      for (var i = 1; i <= maxCards; i++) i,
      for (var i = maxCards - 1; i >= 1; i--) i,
    ];
    return GameConfig(roundSchedule: List.unmodifiable(schedule));
  }

  GameConfig copyWith({
    List<int>? roundSchedule,
    ScoringVariant? scoringVariant,
  }) {
    return GameConfig(
      roundSchedule: roundSchedule ?? this.roundSchedule,
      scoringVariant: scoringVariant ?? this.scoringVariant,
    );
  }
}
