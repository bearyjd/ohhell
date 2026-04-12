import 'dart:math';

import 'package:ohhell_engine/ohhell_engine.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

GameState makeBiddingState({
  required List<PlayingCard> hand,
  Suit? trumpSuit,
  int cardsPerHand = 5,
  Map<String, int> otherBids = const {},
}) {
  final player = Player(id: 'bot1', name: 'Bot', hand: hand);
  final p2 = Player(
    id: 'p2',
    name: 'Player 2',
    bid: otherBids['p2'],
  );
  final p3 = Player(
    id: 'p3',
    name: 'Player 3',
    bid: otherBids['p3'],
  );
  final round = RoundState(
    roundNumber: 1,
    cardsPerHand: cardsPerHand,
    trumpSuit: trumpSuit,
    bids: otherBids,
  );
  return GameState(
    phase: const Bidding(),
    players: [player, p2, p3],
    config: const GameConfig(roundSchedule: [5]),
    currentRound: round,
  );
}

GameState makePlayingState({
  required List<PlayingCard> hand,
  Suit? leadSuit,
  Suit? trumpSuit,
  int bid = 2,
  int tricksWon = 0,
  List<TrickPlay> currentTrickPlays = const [],
  List<Trick> completedTricks = const [],
}) {
  final player = Player(
    id: 'bot1',
    name: 'Bot',
    hand: hand,
    bid: bid,
    tricksWon: tricksWon,
  );
  final trick = Trick(
    plays: currentTrickPlays,
    leadSuit: leadSuit,
    trumpSuit: trumpSuit,
  );
  final round = RoundState(
    roundNumber: 1,
    cardsPerHand: 5,
    trumpSuit: trumpSuit,
    currentTrick: trick,
    tricks: completedTricks,
  );
  return GameState(
    phase: const Playing(),
    players: [
      player,
      const Player(id: 'p2', name: 'Player 2'),
      const Player(id: 'p3', name: 'Player 3'),
    ],
    config: const GameConfig(roundSchedule: [5]),
    currentRound: round,
  );
}

// ---------------------------------------------------------------------------
// RandomBot
// ---------------------------------------------------------------------------

void main() {
  group('BotDifficulty', () {
    test('easy creates RandomBot', () {
      final bot = BotDifficulty.easy.createBot();
      expect(bot, isA<RandomBot>());
    });

    test('medium creates PositionalBot', () {
      final bot = BotDifficulty.medium.createBot();
      expect(bot, isA<PositionalBot>());
    });

    test('hard creates TrackingBot', () {
      final bot = BotDifficulty.hard.createBot();
      expect(bot, isA<TrackingBot>());
    });
  });

  group('RandomBot', () {
    test('chooseBid returns valid range', () {
      final bot = RandomBot(Random(42));
      final state = makeBiddingState(
        hand: const [
          PlayingCard(suit: Suit.spades, rank: Rank.ace),
          PlayingCard(suit: Suit.hearts, rank: Rank.king),
          PlayingCard(suit: Suit.diamonds, rank: Rank.queen),
          PlayingCard(suit: Suit.clubs, rank: Rank.jack),
          PlayingCard(suit: Suit.spades, rank: Rank.ten),
        ],
        cardsPerHand: 5,
      );

      for (var i = 0; i < 100; i++) {
        final bid = bot.chooseBid(state, 'bot1');
        expect(bid, inInclusiveRange(0, 5));
      }
    });

    test('chooseCard returns a legal card', () {
      final bot = RandomBot(Random(42));
      const legal = [
        PlayingCard(suit: Suit.spades, rank: Rank.ace),
        PlayingCard(suit: Suit.spades, rank: Rank.king),
      ];
      final state = makePlayingState(hand: legal);
      for (var i = 0; i < 50; i++) {
        expect(legal, contains(bot.chooseCard(state, 'bot1', legal)));
      }
    });

    test('returns 0 bid when no current round', () {
      final bot = RandomBot(Random(42));
      final state = GameState(
        phase: const Bidding(),
        players: const [Player(id: 'bot1', name: 'Bot')],
        config: const GameConfig(roundSchedule: [1]),
      );
      expect(bot.chooseBid(state, 'bot1'), 0);
    });
  });

  // ---------------------------------------------------------------------------
  // HeuristicBot
  // ---------------------------------------------------------------------------

  group('HeuristicBot', () {
    const bot = HeuristicBot();

    test('bids based on high cards', () {
      final state = makeBiddingState(
        hand: const [
          PlayingCard(suit: Suit.spades, rank: Rank.ace),
          PlayingCard(suit: Suit.hearts, rank: Rank.king),
          PlayingCard(suit: Suit.diamonds, rank: Rank.two),
          PlayingCard(suit: Suit.clubs, rank: Rank.three),
          PlayingCard(suit: Suit.spades, rank: Rank.four),
        ],
      );
      expect(bot.chooseBid(state, 'bot1'), 2);
    });

    test('bid capped at cards per hand', () {
      final state = makeBiddingState(
        hand: const [
          PlayingCard(suit: Suit.spades, rank: Rank.ace),
          PlayingCard(suit: Suit.hearts, rank: Rank.king),
        ],
        cardsPerHand: 2,
      );
      expect(bot.chooseBid(state, 'bot1'), lessThanOrEqualTo(2));
    });

    test('avoids forbidden last-bidder value', () {
      // Other two players bid 2 each → forbidden = 5 - 4 = 1
      final state = makeBiddingState(
        hand: const [
          PlayingCard(suit: Suit.spades, rank: Rank.ace), // 1 high card
          PlayingCard(suit: Suit.hearts, rank: Rank.two),
          PlayingCard(suit: Suit.diamonds, rank: Rank.three),
          PlayingCard(suit: Suit.clubs, rank: Rank.four),
          PlayingCard(suit: Suit.spades, rank: Rank.five),
        ],
        cardsPerHand: 5,
        otherBids: {'p2': 2, 'p3': 2},
      );
      final bid = bot.chooseBid(state, 'bot1');
      expect(bid, isNot(equals(1))); // forbidden = 5-4 = 1
    });

    test('plays highest card when needing tricks', () {
      const legal = [
        PlayingCard(suit: Suit.spades, rank: Rank.two),
        PlayingCard(suit: Suit.spades, rank: Rank.king),
        PlayingCard(suit: Suit.spades, rank: Rank.seven),
      ];
      final state = makePlayingState(hand: legal, bid: 3, tricksWon: 0);
      expect(bot.chooseCard(state, 'bot1', legal).rank, Rank.king);
    });

    test('plays lowest card when bid is met', () {
      const legal = [
        PlayingCard(suit: Suit.spades, rank: Rank.two),
        PlayingCard(suit: Suit.spades, rank: Rank.king),
        PlayingCard(suit: Suit.spades, rank: Rank.seven),
      ];
      final state = makePlayingState(hand: legal, bid: 1, tricksWon: 1);
      expect(bot.chooseCard(state, 'bot1', legal).rank, Rank.two);
    });

    test('returns 0 bid when no current round', () {
      final state = GameState(
        phase: const Bidding(),
        players: const [Player(id: 'bot1', name: 'Bot')],
        config: const GameConfig(roundSchedule: [1]),
      );
      expect(bot.chooseBid(state, 'bot1'), 0);
    });
  });

  // ---------------------------------------------------------------------------
  // PositionalBot
  // ---------------------------------------------------------------------------

  group('PositionalBot', () {
    const bot = PositionalBot();

    test('bids based on high cards', () {
      final state = makeBiddingState(
        hand: const [
          PlayingCard(suit: Suit.spades, rank: Rank.ace),
          PlayingCard(suit: Suit.hearts, rank: Rank.queen),
          PlayingCard(suit: Suit.diamonds, rank: Rank.two),
          PlayingCard(suit: Suit.clubs, rank: Rank.three),
          PlayingCard(suit: Suit.spades, rank: Rank.four),
        ],
      );
      expect(bot.chooseBid(state, 'bot1'), 2); // ace + queen
    });

    test('avoids forbidden last-bidder value', () {
      // Others bid 3+2 = 5 total would equal cardsPerHand when bot bids 0
      // cardsPerHand=5, others=3+1=4, forbidden=1
      final state = makeBiddingState(
        hand: const [
          PlayingCard(suit: Suit.spades, rank: Rank.ace), // would bid 1
          PlayingCard(suit: Suit.hearts, rank: Rank.two),
          PlayingCard(suit: Suit.diamonds, rank: Rank.three),
          PlayingCard(suit: Suit.clubs, rank: Rank.four),
          PlayingCard(suit: Suit.spades, rank: Rank.five),
        ],
        cardsPerHand: 5,
        otherBids: {'p2': 3, 'p3': 1},
      );
      final bid = bot.chooseBid(state, 'bot1');
      expect(bid, isNot(equals(1))); // 5-4=1 is forbidden
    });

    test('leads highest non-trump when needing tricks', () {
      const legal = [
        PlayingCard(suit: Suit.spades, rank: Rank.king),
        PlayingCard(suit: Suit.hearts, rank: Rank.ace), // trump
        PlayingCard(suit: Suit.spades, rank: Rank.two),
      ];
      final state = makePlayingState(
        hand: legal,
        bid: 2,
        tricksWon: 0,
        trumpSuit: Suit.hearts,
      );
      final card = bot.chooseCard(state, 'bot1', legal);
      // Should lead king of spades (highest non-trump), not the trump ace
      expect(card.suit, isNot(Suit.hearts));
      expect(card.rank, Rank.king);
    });

    test('follows with minimum beater when needing tricks', () {
      // Lead suit is spades; current winning card is 7♠
      // We have 9♠ and K♠ — should play 9 (minimum beater)
      const legal = [
        PlayingCard(suit: Suit.spades, rank: Rank.nine),
        PlayingCard(suit: Suit.spades, rank: Rank.king),
      ];
      final state = makePlayingState(
        hand: legal,
        bid: 2,
        tricksWon: 0,
        leadSuit: Suit.spades,
        currentTrickPlays: [
          TrickPlay(
            playerId: 'p2',
            card: const PlayingCard(suit: Suit.spades, rank: Rank.seven),
          ),
        ],
      );
      final card = bot.chooseCard(state, 'bot1', legal);
      expect(card.rank, Rank.nine); // minimum beater, not king
    });

    test('discards lowest non-trump when shedding', () {
      const legal = [
        PlayingCard(suit: Suit.spades, rank: Rank.two),
        PlayingCard(suit: Suit.hearts, rank: Rank.ace), // trump
      ];
      final state = makePlayingState(
        hand: legal,
        bid: 0,
        tricksWon: 0,
        leadSuit: Suit.clubs, // can't follow
        trumpSuit: Suit.hearts,
      );
      final card = bot.chooseCard(state, 'bot1', legal);
      expect(card.suit, Suit.spades); // discard spade, not trump
    });
  });

  // ---------------------------------------------------------------------------
  // TrackingBot
  // ---------------------------------------------------------------------------

  group('TrackingBot', () {
    const bot = TrackingBot();

    test('bids ace as guaranteed win', () {
      final state = makeBiddingState(
        hand: const [
          PlayingCard(suit: Suit.spades, rank: Rank.ace),
          PlayingCard(suit: Suit.hearts, rank: Rank.two),
          PlayingCard(suit: Suit.diamonds, rank: Rank.three),
        ],
        cardsPerHand: 3,
      );
      final bid = bot.chooseBid(state, 'bot1');
      expect(bid, greaterThanOrEqualTo(1)); // at least the ace
    });

    test('does not double-count king when ace is in same hand', () {
      final state = makeBiddingState(
        hand: const [
          PlayingCard(suit: Suit.spades, rank: Rank.ace),
          PlayingCard(suit: Suit.spades, rank: Rank.king),
          PlayingCard(suit: Suit.hearts, rank: Rank.two),
        ],
        cardsPerHand: 3,
      );
      // Only ace counts (king is in same hand, ace already counted)
      final bid = bot.chooseBid(state, 'bot1');
      expect(bid, 1);
    });

    test('counts ruffing potential for void suits with trump', () {
      final state = makeBiddingState(
        hand: const [
          PlayingCard(suit: Suit.hearts, rank: Rank.ace), // trump
          PlayingCard(suit: Suit.hearts, rank: Rank.two), // trump
          // void in spades, diamonds, clubs
        ],
        trumpSuit: Suit.hearts,
        cardsPerHand: 5,
      );
      final bid = bot.chooseBid(state, 'bot1');
      // ace (1) + 3 voids with trump in hand = 4
      expect(bid, greaterThanOrEqualTo(3));
    });

    test('avoids forbidden last-bidder value', () {
      final state = makeBiddingState(
        hand: const [
          PlayingCard(suit: Suit.spades, rank: Rank.ace),
          PlayingCard(suit: Suit.hearts, rank: Rank.two),
          PlayingCard(suit: Suit.diamonds, rank: Rank.three),
          PlayingCard(suit: Suit.clubs, rank: Rank.four),
          PlayingCard(suit: Suit.spades, rank: Rank.five),
        ],
        cardsPerHand: 5,
        otherBids: {'p2': 2, 'p3': 2}, // forbidden = 1
      );
      final bid = bot.chooseBid(state, 'bot1');
      expect(bid, isNot(equals(1)));
    });

    test('leads guaranteed winner when available', () {
      // Ace of spades — guaranteed winner (no higher card in spades)
      const legal = [
        PlayingCard(suit: Suit.spades, rank: Rank.ace),
        PlayingCard(suit: Suit.spades, rank: Rank.two),
        PlayingCard(suit: Suit.hearts, rank: Rank.king),
      ];
      final state = makePlayingState(
        hand: legal,
        bid: 2,
        tricksWon: 0,
      );
      final card = bot.chooseCard(state, 'bot1', legal);
      expect(card, const PlayingCard(suit: Suit.spades, rank: Rank.ace));
    });

    test('uses played-card knowledge: leads king when ace is gone', () {
      // Ace of spades already played — king is now a guaranteed winner
      const legal = [
        PlayingCard(suit: Suit.spades, rank: Rank.king),
        PlayingCard(suit: Suit.spades, rank: Rank.two),
      ];
      const aceOfSpades = PlayingCard(suit: Suit.spades, rank: Rank.ace);
      final state = makePlayingState(
        hand: legal,
        bid: 2,
        tricksWon: 0,
        completedTricks: [
          Trick(
            plays: [
              TrickPlay(playerId: 'p2', card: aceOfSpades),
              TrickPlay(
                playerId: 'p3',
                card: const PlayingCard(suit: Suit.spades, rank: Rank.three),
              ),
            ],
            leadSuit: Suit.spades,
          ),
        ],
      );
      final card = bot.chooseCard(state, 'bot1', legal);
      expect(card.rank, Rank.king); // now a guaranteed winner
    });

    test('over-trumps with minimum trump when following', () {
      // Trick: p2 led 5♦, p3 trumped with 7♥
      // We can't follow diamonds; should play lowest trump that beats 7♥
      const legal = [
        PlayingCard(suit: Suit.hearts, rank: Rank.eight), // barely beats 7
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        PlayingCard(suit: Suit.clubs, rank: Rank.two),
      ];
      final state = makePlayingState(
        hand: legal,
        bid: 2,
        tricksWon: 0,
        leadSuit: Suit.diamonds,
        trumpSuit: Suit.hearts,
        currentTrickPlays: [
          TrickPlay(
            playerId: 'p2',
            card: const PlayingCard(suit: Suit.diamonds, rank: Rank.five),
          ),
          TrickPlay(
            playerId: 'p3',
            card: const PlayingCard(suit: Suit.hearts, rank: Rank.seven),
          ),
        ],
      );
      final card = bot.chooseCard(state, 'bot1', legal);
      expect(card.rank, Rank.eight); // minimum over-trump, not the ace
    });

    test('discards lowest non-trump when shedding and cannot follow', () {
      const legal = [
        PlayingCard(suit: Suit.clubs, rank: Rank.three),
        PlayingCard(suit: Suit.hearts, rank: Rank.ace), // trump
      ];
      final state = makePlayingState(
        hand: legal,
        bid: 0,
        tricksWon: 0,
        leadSuit: Suit.spades,
        trumpSuit: Suit.hearts,
      );
      final card = bot.chooseCard(state, 'bot1', legal);
      expect(card.suit, Suit.clubs); // discard clubs, protect trump ace
    });
  });
}
