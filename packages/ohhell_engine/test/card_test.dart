import 'package:ohhell_engine/ohhell_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Suit', () {
    test('has correct symbols', () {
      expect(Suit.spades.symbol, '\u2660');
      expect(Suit.hearts.symbol, '\u2665');
      expect(Suit.diamonds.symbol, '\u2666');
      expect(Suit.clubs.symbol, '\u2663');
    });

    test('has 4 values', () {
      expect(Suit.values.length, 4);
    });
  });

  group('Rank', () {
    test('has correct values', () {
      expect(Rank.two.value, 2);
      expect(Rank.ace.value, 14);
      expect(Rank.king.value, 13);
      expect(Rank.jack.value, 11);
    });

    test('has 13 values', () {
      expect(Rank.values.length, 13);
    });

    test('ordering by value is correct', () {
      expect(Rank.two.value < Rank.three.value, isTrue);
      expect(Rank.queen.value < Rank.king.value, isTrue);
      expect(Rank.king.value < Rank.ace.value, isTrue);
    });
  });

  group('PlayingCard', () {
    test('equality works', () {
      const a = PlayingCard(suit: Suit.spades, rank: Rank.ace);
      const b = PlayingCard(suit: Suit.spades, rank: Rank.ace);
      const c = PlayingCard(suit: Suit.hearts, rank: Rank.ace);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      const a = PlayingCard(suit: Suit.spades, rank: Rank.ace);
      const b = PlayingCard(suit: Suit.spades, rank: Rank.ace);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('compareTo sorts by suit then rank', () {
      const spadesTwo = PlayingCard(suit: Suit.spades, rank: Rank.two);
      const spadesAce = PlayingCard(suit: Suit.spades, rank: Rank.ace);
      const heartsTwo = PlayingCard(suit: Suit.hearts, rank: Rank.two);

      expect(spadesTwo.compareTo(spadesAce), lessThan(0));
      expect(spadesAce.compareTo(spadesTwo), greaterThan(0));
      expect(spadesTwo.compareTo(heartsTwo), lessThan(0));
    });

    test('toString includes rank and suit symbol', () {
      const card = PlayingCard(suit: Suit.hearts, rank: Rank.queen);
      expect(card.toString(), contains('queen'));
      expect(card.toString(), contains('\u2665'));
    });
  });

  group('Deck', () {
    test('standard deck has 52 cards', () {
      final deck = Deck.standard();
      expect(deck.cards.length, 52);
    });

    test('standard deck has all unique cards', () {
      final deck = Deck.standard();
      final unique = deck.cards.toSet();
      expect(unique.length, 52);
    });

    test('shuffle returns a new deck with same cards', () {
      final deck = Deck.standard();
      final shuffled = deck.shuffle();
      expect(shuffled.cards.length, 52);
      expect(shuffled.cards.toSet(), equals(deck.cards.toSet()));
    });

    test('deal returns correct number of hands and cards', () {
      final deck = Deck.standard().shuffle();
      final result = deck.deal(numPlayers: 4, cardsPerHand: 5);

      expect(result.hands.length, 4);
      for (final hand in result.hands) {
        expect(hand.length, 5);
      }
      expect(result.remaining.length, 52 - 20);
    });

    test('deal throws when not enough cards', () {
      final deck = Deck.standard();
      expect(
        () => deck.deal(numPlayers: 7, cardsPerHand: 8),
        throwsArgumentError,
      );
    });

    test('deal distributes distinct cards', () {
      final deck = Deck.standard().shuffle();
      final result = deck.deal(numPlayers: 3, cardsPerHand: 5);

      final allDealt = result.hands.expand((h) => h).toSet();
      expect(allDealt.length, 15);
    });
  });
}
