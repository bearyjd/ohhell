import 'package:ohhell_engine/ohhell_engine.dart';
import 'package:test/test.dart';

void main() {
  const calculator = ScoreCalculator();

  group('ScoreCalculator - standard variant', () {
    test('exact bid scores 10 + bid', () {
      final scores = calculator.calculateRoundScores(
        bids: {'p1': 3, 'p2': 2},
        tricksWon: {'p1': 3, 'p2': 2},
        variant: ScoringVariant.standard,
      );

      expect(scores['p1'], 13); // 10 + 3
      expect(scores['p2'], 12); // 10 + 2
    });

    test('exact bid of 0 scores 10', () {
      final scores = calculator.calculateRoundScores(
        bids: {'p1': 0},
        tricksWon: {'p1': 0},
        variant: ScoringVariant.standard,
      );

      expect(scores['p1'], 10);
    });

    test('over bid scores tricks won', () {
      final scores = calculator.calculateRoundScores(
        bids: {'p1': 5},
        tricksWon: {'p1': 3},
        variant: ScoringVariant.standard,
      );

      expect(scores['p1'], 3);
    });

    test('under bid scores tricks won', () {
      final scores = calculator.calculateRoundScores(
        bids: {'p1': 1},
        tricksWon: {'p1': 4},
        variant: ScoringVariant.standard,
      );

      expect(scores['p1'], 4);
    });

    test('zero tricks when wrong scores 0', () {
      final scores = calculator.calculateRoundScores(
        bids: {'p1': 3},
        tricksWon: {'p1': 0},
        variant: ScoringVariant.standard,
      );

      expect(scores['p1'], 0);
    });
  });

  group('ScoreCalculator - strict variant', () {
    test('exact bid scores 10 + bid', () {
      final scores = calculator.calculateRoundScores(
        bids: {'p1': 2},
        tricksWon: {'p1': 2},
        variant: ScoringVariant.strict,
      );

      expect(scores['p1'], 12);
    });

    test('wrong bid scores negative tricks won', () {
      final scores = calculator.calculateRoundScores(
        bids: {'p1': 3},
        tricksWon: {'p1': 1},
        variant: ScoringVariant.strict,
      );

      expect(scores['p1'], -1);
    });

    test('over bid with zero tricks scores 0', () {
      final scores = calculator.calculateRoundScores(
        bids: {'p1': 2},
        tricksWon: {'p1': 0},
        variant: ScoringVariant.strict,
      );

      expect(scores['p1'], 0);
    });

    test('under bid scores negative tricks won', () {
      final scores = calculator.calculateRoundScores(
        bids: {'p1': 1},
        tricksWon: {'p1': 4},
        variant: ScoringVariant.strict,
      );

      expect(scores['p1'], -4);
    });
  });

  group('ScoreCalculator - multiple players', () {
    test('scores all players correctly', () {
      final scores = calculator.calculateRoundScores(
        bids: {'p1': 2, 'p2': 1, 'p3': 0},
        tricksWon: {'p1': 2, 'p2': 0, 'p3': 1},
        variant: ScoringVariant.standard,
      );

      expect(scores['p1'], 12); // exact: 10 + 2
      expect(scores['p2'], 0); // wrong: 0 tricks
      expect(scores['p3'], 1); // wrong: 1 trick
    });
  });
}
