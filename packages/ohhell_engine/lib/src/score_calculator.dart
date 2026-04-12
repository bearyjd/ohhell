import 'models/game_config.dart';

/// Calculates round scores based on bids and tricks won.
class ScoreCalculator {
  const ScoreCalculator();

  /// Calculates scores for a round.
  ///
  /// - Standard: exact bid = +10 + bid; wrong = +tricksWon
  /// - Strict: exact bid = +10 + bid; wrong = -tricksWon
  Map<String, int> calculateRoundScores({
    required Map<String, int> bids,
    required Map<String, int> tricksWon,
    required ScoringVariant variant,
  }) {
    final scores = <String, int>{};
    for (final entry in bids.entries) {
      final playerId = entry.key;
      final bid = entry.value;
      final tricks = tricksWon[playerId] ?? 0;

      if (bid == tricks) {
        scores[playerId] = 10 + bid;
      } else {
        scores[playerId] = switch (variant) {
          ScoringVariant.standard => tricks,
          ScoringVariant.strict => -tricks,
        };
      }
    }
    return Map.unmodifiable(scores);
  }
}
