import 'package:ohhell_engine/ohhell_engine.dart';
import 'package:test/test.dart';

void main() {
  const validator = CardValidator();

  const spadesAce = PlayingCard(suit: Suit.spades, rank: Rank.ace);
  const spadesKing = PlayingCard(suit: Suit.spades, rank: Rank.king);
  const heartsAce = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
  const heartsTwo = PlayingCard(suit: Suit.hearts, rank: Rank.two);
  const diamondsThree = PlayingCard(suit: Suit.diamonds, rank: Rank.three);
  const clubsFour = PlayingCard(suit: Suit.clubs, rank: Rank.four);

  group('CardValidator.canPlay', () {
    test('any card is legal when no lead suit', () {
      final hand = [spadesAce, heartsAce, diamondsThree];
      expect(
        validator.canPlay(hand: hand, card: spadesAce, leadSuit: null),
        isTrue,
      );
      expect(
        validator.canPlay(hand: hand, card: heartsAce, leadSuit: null),
        isTrue,
      );
    });

    test('must follow suit if player has cards of lead suit', () {
      final hand = [spadesAce, spadesKing, heartsAce];

      // Spades is lead — must play spade
      expect(
        validator.canPlay(hand: hand, card: spadesAce, leadSuit: Suit.spades),
        isTrue,
      );
      expect(
        validator.canPlay(hand: hand, card: heartsAce, leadSuit: Suit.spades),
        isFalse,
      );
    });

    test('any card legal when player has no cards of lead suit', () {
      final hand = [heartsAce, heartsTwo, diamondsThree];

      // Spades is lead but player has no spades
      expect(
        validator.canPlay(hand: hand, card: heartsAce, leadSuit: Suit.spades),
        isTrue,
      );
      expect(
        validator.canPlay(
          hand: hand,
          card: diamondsThree,
          leadSuit: Suit.spades,
        ),
        isTrue,
      );
    });

    test('card not in hand is not legal', () {
      final hand = [heartsAce, diamondsThree];
      expect(
        validator.canPlay(hand: hand, card: clubsFour, leadSuit: null),
        isFalse,
      );
    });
  });

  group('CardValidator.legalCards', () {
    test('returns all cards when no lead suit', () {
      final hand = [spadesAce, heartsAce, diamondsThree];
      final legal = validator.legalCards(hand: hand, leadSuit: null);
      expect(legal, hand);
    });

    test('returns only lead suit cards when available', () {
      final hand = [spadesAce, spadesKing, heartsAce, diamondsThree];
      final legal = validator.legalCards(hand: hand, leadSuit: Suit.spades);
      expect(legal, [spadesAce, spadesKing]);
    });

    test('returns all cards when no lead suit cards available', () {
      final hand = [heartsAce, diamondsThree, clubsFour];
      final legal = validator.legalCards(hand: hand, leadSuit: Suit.spades);
      expect(legal, hand);
    });
  });
}
