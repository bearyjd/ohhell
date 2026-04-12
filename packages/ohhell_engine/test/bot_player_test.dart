import 'dart:math';

import 'package:ohhell_engine/ohhell_engine.dart';
import 'package:test/test.dart';

void main() {
  GameState makeBiddingState({
    required List<PlayingCard> hand,
    Suit? trumpSuit,
    int cardsPerHand = 5,
  }) {
    final player = Player(id: 'bot1', name: 'Bot', hand: hand);
    final players = [
      player,
      const Player(id: 'p2', name: 'Player 2'),
      const Player(id: 'p3', name: 'Player 3'),
    ];
    final config = const GameConfig(roundSchedule: [5]);
    final round = RoundState(
      roundNumber: 1,
      cardsPerHand: cardsPerHand,
      trumpSuit: trumpSuit,
    );
    return GameState(
      phase: const Bidding(),
      players: players,
      config: config,
      currentRound: round,
    );
  }

  GameState makePlayingState({
    required List<PlayingCard> hand,
    Suit? leadSuit,
    Suit? trumpSuit,
    int bid = 2,
    int tricksWon = 0,
  }) {
    final player = Player(
      id: 'bot1',
      name: 'Bot',
      hand: hand,
      bid: bid,
      tricksWon: tricksWon,
    );
    final players = [
      player,
      const Player(id: 'p2', name: 'Player 2'),
      const Player(id: 'p3', name: 'Player 3'),
    ];
    final config = const GameConfig(roundSchedule: [5]);
    final trick = Trick(leadSuit: leadSuit, trumpSuit: trumpSuit);
    final round = RoundState(
      roundNumber: 1,
      cardsPerHand: 5,
      trumpSuit: trumpSuit,
      currentTrick: trick,
    );
    return GameState(
      phase: const Playing(),
      players: players,
      config: config,
      currentRound: round,
    );
  }

  group('RandomBot', () {
    test('chooseBid returns valid bid range', () {
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
        expect(bid, greaterThanOrEqualTo(0));
        expect(bid, lessThanOrEqualTo(5));
      }
    });

    test('chooseCard returns a card from legal cards', () {
      final bot = RandomBot(Random(42));
      const legalCards = [
        PlayingCard(suit: Suit.spades, rank: Rank.ace),
        PlayingCard(suit: Suit.spades, rank: Rank.king),
      ];
      final state = makePlayingState(hand: legalCards);

      for (var i = 0; i < 50; i++) {
        final card = bot.chooseCard(state, 'bot1', legalCards);
        expect(legalCards.contains(card), isTrue);
      }
    });

    test('chooseBid returns 0 when no current round', () {
      final bot = RandomBot(Random(42));
      final state = GameState(
        phase: const Bidding(),
        players: const [Player(id: 'bot1', name: 'Bot')],
        config: const GameConfig(roundSchedule: [1]),
      );
      expect(bot.chooseBid(state, 'bot1'), 0);
    });
  });

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

      final bid = bot.chooseBid(state, 'bot1');
      // ace + king = 2 high cards
      expect(bid, 2);
    });

    test('bid capped at cards per hand', () {
      final state = makeBiddingState(
        hand: const [
          PlayingCard(suit: Suit.spades, rank: Rank.ace),
          PlayingCard(suit: Suit.hearts, rank: Rank.king),
        ],
        cardsPerHand: 2,
      );

      final bid = bot.chooseBid(state, 'bot1');
      expect(bid, lessThanOrEqualTo(2));
    });

    test('plays highest card when needing tricks', () {
      const legalCards = [
        PlayingCard(suit: Suit.spades, rank: Rank.two),
        PlayingCard(suit: Suit.spades, rank: Rank.king),
        PlayingCard(suit: Suit.spades, rank: Rank.seven),
      ];
      final state = makePlayingState(hand: legalCards, bid: 3, tricksWon: 0);

      final card = bot.chooseCard(state, 'bot1', legalCards);
      expect(card.rank, Rank.king);
    });

    test('plays lowest card when bid is met', () {
      const legalCards = [
        PlayingCard(suit: Suit.spades, rank: Rank.two),
        PlayingCard(suit: Suit.spades, rank: Rank.king),
        PlayingCard(suit: Suit.spades, rank: Rank.seven),
      ];
      final state = makePlayingState(hand: legalCards, bid: 1, tricksWon: 1);

      final card = bot.chooseCard(state, 'bot1', legalCards);
      expect(card.rank, Rank.two);
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
}
