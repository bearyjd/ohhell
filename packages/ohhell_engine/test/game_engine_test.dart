import 'dart:math';

import 'package:ohhell_engine/ohhell_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = GameEngine();

  List<Player> makePlayers(int count) {
    return [
      for (var i = 0; i < count; i++) Player(id: 'p$i', name: 'Player $i'),
    ];
  }

  group('GameEngine.startGame', () {
    test('creates game in dealing phase', () {
      final state = engine.startGame(
        makePlayers(3),
        const GameConfig(roundSchedule: [1, 2, 3]),
      );
      expect(state.phase, isA<Dealing>());
      expect(state.players.length, 3);
      expect(state.rounds, isEmpty);
    });

    test('rejects too few players', () {
      expect(
        () => engine.startGame(
          makePlayers(2),
          const GameConfig(roundSchedule: [1]),
        ),
        throwsA(isA<InvalidGameStateException>()),
      );
    });

    test('rejects too many players', () {
      expect(
        () => engine.startGame(
          makePlayers(8),
          const GameConfig(roundSchedule: [1]),
        ),
        throwsA(isA<InvalidGameStateException>()),
      );
    });

    test('rejects empty round schedule', () {
      expect(
        () => engine.startGame(
          makePlayers(3),
          const GameConfig(roundSchedule: []),
        ),
        throwsA(isA<InvalidGameStateException>()),
      );
    });
  });

  group('GameEngine.dealRound', () {
    test('deals cards and moves to bidding phase', () {
      var state = engine.startGame(
        makePlayers(3),
        const GameConfig(roundSchedule: [2, 3]),
      );

      state = engine.dealRound(state, random: Random(42));

      expect(state.phase, isA<Bidding>());
      expect(state.currentRound, isNotNull);
      expect(state.currentRound?.roundNumber, 1);
      expect(state.currentRound?.cardsPerHand, 2);

      for (final player in state.players) {
        expect(player.hand.length, 2);
      }
    });

    test('sets trump suit from remaining cards', () {
      var state = engine.startGame(
        makePlayers(3),
        const GameConfig(roundSchedule: [5]),
      );

      state = engine.dealRound(state, random: Random(42));

      // 3 players * 5 cards = 15 dealt, 37 remaining — trump should be set
      expect(state.currentRound?.trumpSuit, isNotNull);
    });

    test('throws if not in dealing phase', () {
      var state = engine.startGame(
        makePlayers(3),
        const GameConfig(roundSchedule: [1]),
      );
      state = engine.dealRound(state, random: Random(42));

      // Now in bidding phase
      expect(
        () => engine.dealRound(state),
        throwsA(isA<InvalidGameStateException>()),
      );
    });
  });

  group('GameEngine.placeBid', () {
    test('records bid and advances to next player', () {
      var state = engine.startGame(
        makePlayers(3),
        const GameConfig(roundSchedule: [2]),
      );
      state = engine.dealRound(state, random: Random(42));

      state = engine.placeBid(state, 'p0', 1);

      expect(state.phase, isA<Bidding>());
      expect(state.currentRound?.bids['p0'], 1);
      expect(state.currentRound?.currentPlayerIndex, 1);
    });

    test('moves to playing after all bids', () {
      var state = engine.startGame(
        makePlayers(3),
        const GameConfig(roundSchedule: [2]),
      );
      state = engine.dealRound(state, random: Random(42));

      state = engine.placeBid(state, 'p0', 1);
      state = engine.placeBid(state, 'p1', 0);
      state = engine.placeBid(state, 'p2', 1);

      expect(state.phase, isA<Playing>());
    });

    test('throws if wrong player bids', () {
      var state = engine.startGame(
        makePlayers(3),
        const GameConfig(roundSchedule: [2]),
      );
      state = engine.dealRound(state, random: Random(42));

      expect(
        () => engine.placeBid(state, 'p1', 1),
        throwsA(isA<IllegalMoveException>()),
      );
    });

    test('throws if not in bidding phase', () {
      final state = engine.startGame(
        makePlayers(3),
        const GameConfig(roundSchedule: [1]),
      );

      expect(
        () => engine.placeBid(state, 'p0', 1),
        throwsA(isA<IllegalMoveException>()),
      );
    });

    test('throws for negative bid', () {
      var state = engine.startGame(
        makePlayers(3),
        const GameConfig(roundSchedule: [2]),
      );
      state = engine.dealRound(state, random: Random(42));

      expect(
        () => engine.placeBid(state, 'p0', -1),
        throwsA(isA<IllegalMoveException>()),
      );
    });
  });

  group('GameEngine.playCard', () {
    test('throws if not in playing phase', () {
      var state = engine.startGame(
        makePlayers(3),
        const GameConfig(roundSchedule: [1]),
      );
      state = engine.dealRound(state, random: Random(42));

      expect(
        () => engine.playCard(state, 'p0', state.players[0].hand.first),
        throwsA(isA<IllegalMoveException>()),
      );
    });

    test('throws if wrong player plays', () {
      var state = engine.startGame(
        makePlayers(3),
        const GameConfig(roundSchedule: [1]),
      );
      state = engine.dealRound(state, random: Random(42));
      state = engine.placeBid(state, 'p0', 0);
      state = engine.placeBid(state, 'p1', 0);
      state = engine.placeBid(state, 'p2', 1);

      expect(
        () => engine.playCard(state, 'p1', state.players[1].hand.first),
        throwsA(isA<IllegalMoveException>()),
      );
    });

    test('throws if card not in hand', () {
      var state = engine.startGame(
        makePlayers(3),
        const GameConfig(roundSchedule: [1]),
      );
      state = engine.dealRound(state, random: Random(42));
      state = engine.placeBid(state, 'p0', 0);
      state = engine.placeBid(state, 'p1', 0);
      state = engine.placeBid(state, 'p2', 0);

      expect(
        () => engine.playCard(
          state,
          'p0',
          const PlayingCard(suit: Suit.spades, rank: Rank.ace),
        ),
        // Could be IllegalMoveException for card not in hand
        // or for must-follow-suit; depends on what's in hand
        throwsA(isA<IllegalMoveException>()),
      );
    });
  });

  group('GameEngine.evaluateTrick', () {
    test('highest lead suit card wins with no trump', () {
      const trick = Trick(
        plays: [
          TrickPlay(
            playerId: 'p0',
            card: PlayingCard(suit: Suit.spades, rank: Rank.ten),
          ),
          TrickPlay(
            playerId: 'p1',
            card: PlayingCard(suit: Suit.spades, rank: Rank.king),
          ),
          TrickPlay(
            playerId: 'p2',
            card: PlayingCard(suit: Suit.spades, rank: Rank.five),
          ),
        ],
        leadSuit: Suit.spades,
      );

      expect(engine.evaluateTrick(trick, null), 'p1');
    });

    test('trump beats lead suit', () {
      const trick = Trick(
        plays: [
          TrickPlay(
            playerId: 'p0',
            card: PlayingCard(suit: Suit.spades, rank: Rank.ace),
          ),
          TrickPlay(
            playerId: 'p1',
            card: PlayingCard(suit: Suit.hearts, rank: Rank.two),
          ),
          TrickPlay(
            playerId: 'p2',
            card: PlayingCard(suit: Suit.spades, rank: Rank.king),
          ),
        ],
        leadSuit: Suit.spades,
        trumpSuit: Suit.hearts,
      );

      expect(engine.evaluateTrick(trick, Suit.hearts), 'p1');
    });

    test('higher trump beats lower trump', () {
      const trick = Trick(
        plays: [
          TrickPlay(
            playerId: 'p0',
            card: PlayingCard(suit: Suit.spades, rank: Rank.ace),
          ),
          TrickPlay(
            playerId: 'p1',
            card: PlayingCard(suit: Suit.hearts, rank: Rank.two),
          ),
          TrickPlay(
            playerId: 'p2',
            card: PlayingCard(suit: Suit.hearts, rank: Rank.king),
          ),
        ],
        leadSuit: Suit.spades,
        trumpSuit: Suit.hearts,
      );

      expect(engine.evaluateTrick(trick, Suit.hearts), 'p2');
    });

    test('non-lead non-trump card loses', () {
      const trick = Trick(
        plays: [
          TrickPlay(
            playerId: 'p0',
            card: PlayingCard(suit: Suit.spades, rank: Rank.five),
          ),
          TrickPlay(
            playerId: 'p1',
            card: PlayingCard(suit: Suit.diamonds, rank: Rank.ace),
          ),
          TrickPlay(
            playerId: 'p2',
            card: PlayingCard(suit: Suit.spades, rank: Rank.three),
          ),
        ],
        leadSuit: Suit.spades,
        trumpSuit: Suit.hearts,
      );

      // p1 played diamonds (not lead, not trump) — p0 wins with 5 of spades
      expect(engine.evaluateTrick(trick, Suit.hearts), 'p0');
    });

    test('throws for empty trick', () {
      const trick = Trick();
      expect(
        () => engine.evaluateTrick(trick, null),
        throwsA(isA<InvalidGameStateException>()),
      );
    });
  });

  group('Full 3-player game simulation', () {
    test('plays a complete 1-card round game', () {
      var state = engine.startGame(
        makePlayers(3),
        const GameConfig(roundSchedule: [1]),
      );

      // Deal
      state = engine.dealRound(state, random: Random(99));
      expect(state.phase, isA<Bidding>());

      // Bid
      state = engine.placeBid(state, 'p0', 0);
      state = engine.placeBid(state, 'p1', 1);
      state = engine.placeBid(state, 'p2', 0);
      expect(state.phase, isA<Playing>());

      // Play single trick — each player plays their only card
      final card0 = state.players[0].hand.first;
      final card1 = state.players[1].hand.first;
      final card2 = state.players[2].hand.first;

      state = engine.playCard(state, 'p0', card0);
      state = engine.playCard(state, 'p1', card1);
      state = engine.playCard(state, 'p2', card2);

      // Game should be over (only 1 round)
      expect(state.phase, isA<GameEnd>());
      expect(state.winnerId, isNotNull);
      expect(state.rounds.length, 1);
    });

    test('plays a complete multi-round game', () {
      var state = engine.startGame(
        makePlayers(3),
        const GameConfig(roundSchedule: [1, 2]),
      );

      // Round 1
      state = engine.dealRound(state, random: Random(42));
      state = engine.placeBid(state, 'p0', 0);
      state = engine.placeBid(state, 'p1', 0);
      state = engine.placeBid(state, 'p2', 1);

      // Play 1 trick
      state = engine.playCard(state, 'p0', state.players[0].hand.first);
      state = engine.playCard(state, 'p1', state.players[1].hand.first);
      state = engine.playCard(state, 'p2', state.players[2].hand.first);

      // Should advance to dealing for round 2
      expect(state.phase, isA<Dealing>());
      expect(state.rounds.length, 1);

      // Round 2
      state = engine.dealRound(state, random: Random(43));
      expect(state.currentRound?.cardsPerHand, 2);

      state = engine.placeBid(state, 'p0', 1);
      state = engine.placeBid(state, 'p1', 0);
      state = engine.placeBid(state, 'p2', 1);

      // Play 2 tricks
      for (var trick = 0; trick < 2; trick++) {
        final currentIdx = state.currentRound?.currentPlayerIndex ?? 0;
        final order = <int>[
          currentIdx,
          (currentIdx + 1) % 3,
          (currentIdx + 2) % 3,
        ];

        for (final idx in order) {
          final player = state.players[idx];
          final leadSuit = state.currentRound?.currentTrick.leadSuit;
          const validator = CardValidator();
          final legal = validator.legalCards(
            hand: player.hand,
            leadSuit: leadSuit,
          );
          state = engine.playCard(state, player.id, legal.first);
        }
      }

      // Game over
      expect(state.phase, isA<GameEnd>());
      expect(state.winnerId, isNotNull);
      expect(state.rounds.length, 2);

      // Scores should be computed
      for (final player in state.players) {
        expect(player.totalScore, isNotNull);
      }
    });
  });

  group('GameConfig', () {
    test('defaultFor creates valid schedule for 3 players', () {
      final config = GameConfig.defaultFor(3);
      // (52-1) ~/ 3 = 17 max
      expect(config.roundSchedule.first, 1);
      expect(config.roundSchedule.last, 1);
      // Goes up to 17 and back
      expect(config.roundSchedule.length, 17 * 2 - 1);
    });

    test('defaultFor creates valid schedule for 7 players', () {
      final config = GameConfig.defaultFor(7);
      // (52-1) ~/ 7 = 7 max
      expect(config.roundSchedule.first, 1);
      expect(config.roundSchedule.last, 1);
      expect(config.roundSchedule.length, 7 * 2 - 1);
    });

    test('defaultFor rejects invalid player counts', () {
      expect(() => GameConfig.defaultFor(2), throwsArgumentError);
      expect(() => GameConfig.defaultFor(8), throwsArgumentError);
    });

    test('copyWith preserves values', () {
      const config = GameConfig(
        roundSchedule: [1, 2, 3],
        scoringVariant: ScoringVariant.strict,
      );
      final copy = config.copyWith();
      expect(copy.roundSchedule, config.roundSchedule);
      expect(copy.scoringVariant, config.scoringVariant);
    });

    test('copyWith overrides values', () {
      const config = GameConfig(roundSchedule: [1, 2, 3]);
      final copy = config.copyWith(scoringVariant: ScoringVariant.strict);
      expect(copy.scoringVariant, ScoringVariant.strict);
    });
  });
}
