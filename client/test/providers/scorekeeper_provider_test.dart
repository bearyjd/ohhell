import 'package:flutter_test/flutter_test.dart';
import 'package:ohhell_client/src/providers/scorekeeper_provider.dart';

void main() {
  group('ScorekeeperState', () {
    test('has correct defaults', () {
      const state = ScorekeeperState();
      expect(state.playerNames, isEmpty);
      expect(state.roundSchedule, isEmpty);
      expect(state.currentRoundIndex, 0);
      expect(state.bids, isEmpty);
      expect(state.tricks, isEmpty);
      expect(state.currentRoundBids, isEmpty);
      expect(state.currentRoundTricks, isEmpty);
    });
  });

  group('ScorekeeperNotifier', () {
    late ScorekeeperNotifier notifier;

    setUp(() => notifier = ScorekeeperNotifier());

    // ── startGame ───────────────────────────────────────────────────────────

    group('startGame', () {
      test('sets player names', () {
        notifier.startGame(['Alice', 'Bob', 'Carol']);
        expect(notifier.state.playerNames, ['Alice', 'Bob', 'Carol']);
      });

      test('computes round schedule for 3 players (1..17..1 = 33 rounds)', () {
        notifier.startGame(['Alice', 'Bob', 'Carol']);
        // 51 ~/ 3 = 17 → 1…17…1
        expect(notifier.state.roundSchedule.first, 1);
        expect(notifier.state.roundSchedule.last, 1);
        expect(notifier.state.roundSchedule.length, 33);
      });

      test('computes round schedule for 5 players (1..10..1 = 19 rounds)', () {
        notifier.startGame(['A', 'B', 'C', 'D', 'E']);
        // 51 ~/ 5 = 10 → 1…10…1
        expect(notifier.state.roundSchedule.first, 1);
        expect(notifier.state.roundSchedule.last, 1);
        expect(notifier.state.roundSchedule.length, 19);
      });

      test('sets currentRoundIndex to 0', () {
        notifier.startGame(['Alice', 'Bob', 'Carol']);
        expect(notifier.state.currentRoundIndex, 0);
      });

      test('initialises all tracking collections as empty', () {
        notifier.startGame(['Alice', 'Bob', 'Carol']);
        expect(notifier.state.bids, isEmpty);
        expect(notifier.state.tricks, isEmpty);
        expect(notifier.state.currentRoundBids, isEmpty);
        expect(notifier.state.currentRoundTricks, isEmpty);
      });

      test('throws ArgumentError for fewer than 3 players', () {
        expect(
          () => notifier.startGame(['Alice', 'Bob']),
          throwsArgumentError,
        );
      });

      test('throws ArgumentError for more than 7 players', () {
        expect(
          () => notifier.startGame(['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']),
          throwsArgumentError,
        );
      });
    });

    // ── setBid / setTricks ──────────────────────────────────────────────────

    group('setBid', () {
      setUp(() => notifier.startGame(['Alice', 'Bob', 'Carol']));

      test('records bid for named player', () {
        notifier.setBid('Alice', 2);
        expect(notifier.state.currentRoundBids['Alice'], 2);
      });

      test('overwrites previous bid for same player', () {
        notifier.setBid('Alice', 2);
        notifier.setBid('Alice', 0);
        expect(notifier.state.currentRoundBids['Alice'], 0);
      });

      test('records bids independently per player', () {
        notifier.setBid('Alice', 1);
        notifier.setBid('Bob', 2);
        expect(notifier.state.currentRoundBids['Alice'], 1);
        expect(notifier.state.currentRoundBids['Bob'], 2);
      });
    });

    group('setTricks', () {
      setUp(() => notifier.startGame(['Alice', 'Bob', 'Carol']));

      test('records tricks for named player', () {
        notifier.setTricks('Alice', 1);
        expect(notifier.state.currentRoundTricks['Alice'], 1);
      });

      test('overwrites previous tricks for same player', () {
        notifier.setTricks('Bob', 3);
        notifier.setTricks('Bob', 1);
        expect(notifier.state.currentRoundTricks['Bob'], 1);
      });
    });

    // ── endRound ────────────────────────────────────────────────────────────

    group('endRound', () {
      test('throws StateError when trick sum ≠ cardsPerHand', () {
        notifier.startGame(['Alice', 'Bob', 'Carol']);
        // Round 0 → 1 card; entering sum of 2 should fail
        notifier.setBid('Alice', 1);
        notifier.setBid('Bob', 0);
        notifier.setBid('Carol', 0);
        notifier.setTricks('Alice', 1);
        notifier.setTricks('Bob', 1); // sum = 2, should be 1
        notifier.setTricks('Carol', 0);
        expect(() => notifier.endRound(), throwsStateError);
      });

      group('after valid round 0 (1 card, Alice wins)', () {
        setUp(() {
          notifier.startGame(['Alice', 'Bob', 'Carol']);
          // Alice bids 1 wins 1; Bob/Carol bid 0 win 0
          notifier.setBid('Alice', 1);
          notifier.setBid('Bob', 0);
          notifier.setBid('Carol', 0);
          notifier.setTricks('Alice', 1);
          notifier.setTricks('Bob', 0);
          notifier.setTricks('Carol', 0);
          notifier.endRound();
        });

        test('records bids for completed round', () {
          expect(notifier.state.bids.length, 1);
          expect(notifier.state.bids[0]['Alice'], 1);
          expect(notifier.state.bids[0]['Bob'], 0);
        });

        test('records tricks for completed round', () {
          expect(notifier.state.tricks.length, 1);
          expect(notifier.state.tricks[0]['Alice'], 1);
          expect(notifier.state.tricks[0]['Bob'], 0);
        });

        test('advances currentRoundIndex to 1', () {
          expect(notifier.state.currentRoundIndex, 1);
        });

        test('clears currentRoundBids and currentRoundTricks', () {
          expect(notifier.state.currentRoundBids, isEmpty);
          expect(notifier.state.currentRoundTricks, isEmpty);
        });

        test('exact bid gives +10 + tricks (Alice: 10+1=11)', () {
          expect(notifier.roundScore(0, 'Alice'), 11);
        });

        test('exact bid of 0 gives +10 + 0 = 10 (Bob)', () {
          expect(notifier.roundScore(0, 'Bob'), 10);
        });

        test('isGameOver is false mid-game', () {
          expect(notifier.isGameOver, isFalse);
        });
      });

      test('wrong bid scores tricks won only (no +10 bonus)', () {
        notifier.startGame(['Alice', 'Bob', 'Carol']);
        // Alice bids 1 but wins 0 → wrong → score = 0
        // Carol bids 0 but wins 1 → wrong → score = 1
        notifier.setBid('Alice', 1);
        notifier.setBid('Bob', 0);
        notifier.setBid('Carol', 0);
        notifier.setTricks('Alice', 0);
        notifier.setTricks('Bob', 0);
        notifier.setTricks('Carol', 1);
        notifier.endRound();

        expect(notifier.roundScore(0, 'Alice'), 0);
        expect(notifier.roundScore(0, 'Carol'), 1);
      });
    });

    // ── runningTotals ───────────────────────────────────────────────────────

    group('runningTotals', () {
      test('returns zeros for all players before any rounds', () {
        notifier.startGame(['Alice', 'Bob', 'Carol']);
        final totals = notifier.runningTotals;
        expect(totals['Alice'], 0);
        expect(totals['Bob'], 0);
        expect(totals['Carol'], 0);
      });

      test('sums scores across two completed rounds', () {
        notifier.startGame(['Alice', 'Bob', 'Carol']);

        // Round 0 (1 card): Alice exact-bids 1, Bob/Carol exact-bid 0
        // Alice=11, Bob=10, Carol=10
        notifier.setBid('Alice', 1);
        notifier.setBid('Bob', 0);
        notifier.setBid('Carol', 0);
        notifier.setTricks('Alice', 1);
        notifier.setTricks('Bob', 0);
        notifier.setTricks('Carol', 0);
        notifier.endRound();

        // Round 1 (2 cards): Alice exact-bids 0, Bob/Carol exact-bid 1
        // Alice=10, Bob=11, Carol=11
        notifier.setBid('Alice', 0);
        notifier.setBid('Bob', 1);
        notifier.setBid('Carol', 1);
        notifier.setTricks('Alice', 0);
        notifier.setTricks('Bob', 1);
        notifier.setTricks('Carol', 1);
        notifier.endRound();

        final totals = notifier.runningTotals;
        expect(totals['Alice'], 21); // 11 + 10
        expect(totals['Bob'], 21); // 10 + 11
        expect(totals['Carol'], 21); // 10 + 11
      });
    });

    // ── isGameOver / winner ─────────────────────────────────────────────────

    group('isGameOver', () {
      test('is false when rounds remain', () {
        notifier.startGame(['Alice', 'Bob', 'Carol']);
        expect(notifier.isGameOver, isFalse);
      });

      test('is true after all 33 rounds completed for 3 players', () {
        notifier.startGame(['Alice', 'Bob', 'Carol']);
        for (final cards in notifier.state.roundSchedule) {
          notifier.setBid('Alice', cards);
          notifier.setBid('Bob', 0);
          notifier.setBid('Carol', 0);
          notifier.setTricks('Alice', cards);
          notifier.setTricks('Bob', 0);
          notifier.setTricks('Carol', 0);
          notifier.endRound();
        }
        expect(notifier.isGameOver, isTrue);
      });
    });

    group('winner', () {
      test('returns null before any rounds played', () {
        notifier.startGame(['Alice', 'Bob', 'Carol']);
        expect(notifier.winner, isNull);
      });

      test('returns player with highest running total', () {
        notifier.startGame(['Alice', 'Bob', 'Carol']);
        // Alice gets 11, others get 10
        notifier.setBid('Alice', 1);
        notifier.setBid('Bob', 0);
        notifier.setBid('Carol', 0);
        notifier.setTricks('Alice', 1);
        notifier.setTricks('Bob', 0);
        notifier.setTricks('Carol', 0);
        notifier.endRound();
        expect(notifier.winner, 'Alice');
      });
    });

    // ── exportText ──────────────────────────────────────────────────────────

    group('exportText', () {
      setUp(() {
        notifier.startGame(['Alice', 'Bob', 'Carol']);
        notifier.setBid('Alice', 1);
        notifier.setBid('Bob', 0);
        notifier.setBid('Carol', 0);
        notifier.setTricks('Alice', 1);
        notifier.setTricks('Bob', 0);
        notifier.setTricks('Carol', 0);
        notifier.endRound();
      });

      test('contains player names', () {
        final text = notifier.exportText();
        expect(text, contains('Alice'));
        expect(text, contains('Bob'));
        expect(text, contains('Carol'));
      });

      test('contains TOTAL row', () {
        final text = notifier.exportText();
        expect(text, contains('TOTAL'));
      });

      test('contains Alice score (11)', () {
        final text = notifier.exportText();
        expect(text, contains('11'));
      });

      test('contains app attribution', () {
        final text = notifier.exportText();
        expect(text, contains('Oh Hell'));
        expect(text, contains('Generated by'));
      });

      test('includes crown and winner on game over', () {
        // Play remaining rounds so game is over
        notifier.startGame(['Alice', 'Bob', 'Carol']);
        for (final cards in notifier.state.roundSchedule) {
          notifier.setBid('Alice', cards);
          notifier.setBid('Bob', 0);
          notifier.setBid('Carol', 0);
          notifier.setTricks('Alice', cards);
          notifier.setTricks('Bob', 0);
          notifier.setTricks('Carol', 0);
          notifier.endRound();
        }
        final text = notifier.exportText();
        expect(text, contains('👑'));
        expect(text, contains('wins'));
      });
    });
  });
}
