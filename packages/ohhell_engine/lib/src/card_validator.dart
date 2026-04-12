import 'models/card.dart';

/// Validates whether a card can be legally played.
class CardValidator {
  const CardValidator();

  /// Returns whether [card] can be played from [hand] given the
  /// current [leadSuit].
  ///
  /// Rules:
  /// - If no lead suit (first play of trick), any card is legal.
  /// - Must follow suit if player has cards of the lead suit.
  /// - If no cards of lead suit, any card is legal.
  bool canPlay({
    required List<PlayingCard> hand,
    required PlayingCard card,
    required Suit? leadSuit,
  }) {
    // Card must be in hand
    if (!hand.contains(card)) return false;

    // No lead suit means any card is legal (first play)
    if (leadSuit == null) return true;

    // If player has cards of the lead suit, must follow suit
    final hasLeadSuit = hand.any((c) => c.suit == leadSuit);
    if (hasLeadSuit) return card.suit == leadSuit;

    // No cards of lead suit — any card is legal
    return true;
  }

  /// Returns all legal cards from [hand] given the current [leadSuit].
  List<PlayingCard> legalCards({
    required List<PlayingCard> hand,
    required Suit? leadSuit,
  }) {
    return hand
        .where((c) => canPlay(hand: hand, card: c, leadSuit: leadSuit))
        .toList();
  }
}
