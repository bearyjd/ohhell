import 'dart:math';

/// Suits in a standard deck of cards.
enum Suit {
  spades('\u2660'),
  hearts('\u2665'),
  diamonds('\u2666'),
  clubs('\u2663');

  const Suit(this.symbol);

  /// Display symbol for this suit.
  final String symbol;
}

/// Card ranks ordered by value (two=2 through ace=14).
enum Rank {
  two(2),
  three(3),
  four(4),
  five(5),
  six(6),
  seven(7),
  eight(8),
  nine(9),
  ten(10),
  jack(11),
  queen(12),
  king(13),
  ace(14);

  const Rank(this.value);

  /// Numeric value of this rank.
  final int value;
}

/// An immutable playing card with a suit and rank.
class PlayingCard implements Comparable<PlayingCard> {
  const PlayingCard({required this.suit, required this.rank});

  final Suit suit;
  final Rank rank;

  @override
  int compareTo(PlayingCard other) {
    final suitCompare = suit.index.compareTo(other.suit.index);
    if (suitCompare != 0) return suitCompare;
    return rank.value.compareTo(other.rank.value);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayingCard && suit == other.suit && rank == other.rank;

  @override
  int get hashCode => Object.hash(suit, rank);

  @override
  String toString() => '${rank.name}${suit.symbol}';
}

/// Result of dealing cards from a deck.
class DealResult {
  const DealResult({required this.hands, required this.remaining});

  final List<List<PlayingCard>> hands;
  final List<PlayingCard> remaining;
}

/// A deck of playing cards.
class Deck {
  const Deck._(this.cards);

  /// Creates a sorted 52-card deck.
  factory Deck.standard() {
    final cards = <PlayingCard>[
      for (final suit in Suit.values)
        for (final rank in Rank.values) PlayingCard(suit: suit, rank: rank),
    ];
    return Deck._(List.unmodifiable(cards));
  }

  final List<PlayingCard> cards;

  /// Returns a new Deck with cards in random order.
  Deck shuffle([Random? random]) {
    final shuffled = List<PlayingCard>.of(cards)..shuffle(random);
    return Deck._(List.unmodifiable(shuffled));
  }

  /// Deals [cardsPerHand] cards to [numPlayers] players.
  ///
  /// Returns a [DealResult] with hands and remaining cards.
  DealResult deal({required int numPlayers, required int cardsPerHand}) {
    final totalNeeded = numPlayers * cardsPerHand;
    if (totalNeeded > cards.length) {
      throw ArgumentError(
        'Not enough cards: need $totalNeeded but deck has ${cards.length}',
      );
    }

    final hands = <List<PlayingCard>>[];
    for (var p = 0; p < numPlayers; p++) {
      final hand = <PlayingCard>[];
      for (var c = 0; c < cardsPerHand; c++) {
        hand.add(cards[p + c * numPlayers]);
      }
      hands.add(List<PlayingCard>.unmodifiable(hand));
    }

    final remaining = List<PlayingCard>.unmodifiable(
      cards.sublist(totalNeeded),
    );
    return DealResult(hands: List.unmodifiable(hands), remaining: remaining);
  }
}
