import 'dart:math';

import 'models/card.dart';
import 'models/game_state.dart';

/// Interface for bot players.
abstract interface class BotPlayer {
  /// Chooses a bid based on the current game state.
  int chooseBid(GameState state, String myPlayerId);

  /// Chooses a card to play from the legal cards.
  PlayingCard chooseCard(
    GameState state,
    String myPlayerId,
    List<PlayingCard> legalCards,
  );
}

/// A bot that makes random legal moves.
class RandomBot implements BotPlayer {
  RandomBot([Random? random]) : _random = random ?? Random();

  final Random _random;

  @override
  int chooseBid(GameState state, String myPlayerId) {
    final round = state.currentRound;
    if (round == null) return 0;
    // Bid between 0 and cards per hand
    return _random.nextInt(round.cardsPerHand + 1);
  }

  @override
  PlayingCard chooseCard(
    GameState state,
    String myPlayerId,
    List<PlayingCard> legalCards,
  ) {
    return legalCards[_random.nextInt(legalCards.length)];
  }
}

/// A bot that uses simple heuristics.
///
/// Bidding: counts high cards (jack+) in hand as expected wins.
/// Playing: if under-bid (need more tricks), plays highest legal card;
/// otherwise plays lowest legal card to avoid winning unnecessary tricks.
class HeuristicBot implements BotPlayer {
  const HeuristicBot();

  @override
  int chooseBid(GameState state, String myPlayerId) {
    final player = state.players.firstWhere((p) => p.id == myPlayerId);
    final round = state.currentRound;
    if (round == null) return 0;

    // Count high cards (jack and above) as likely tricks
    var bid = 0;
    for (final card in player.hand) {
      if (card.rank.value >= Rank.jack.value) {
        bid++;
      }
      // Trump cards below jack still have some value
      if (round.trumpSuit != null &&
          card.suit == round.trumpSuit &&
          card.rank.value >= Rank.nine.value &&
          card.rank.value < Rank.jack.value) {
        bid++;
      }
    }

    // Cap bid at cards per hand
    if (bid > round.cardsPerHand) {
      bid = round.cardsPerHand;
    }

    return bid;
  }

  @override
  PlayingCard chooseCard(
    GameState state,
    String myPlayerId,
    List<PlayingCard> legalCards,
  ) {
    final player = state.players.firstWhere((p) => p.id == myPlayerId);
    final bid = player.bid ?? 0;
    final tricksNeeded = bid - player.tricksWon;

    // Sort legal cards by rank
    final sorted = List<PlayingCard>.of(legalCards)
      ..sort((a, b) => a.rank.value.compareTo(b.rank.value));

    if (tricksNeeded > 0) {
      // Need more tricks — play highest card
      return sorted.last;
    } else {
      // Met or exceeded bid — play lowest card
      return sorted.first;
    }
  }
}
