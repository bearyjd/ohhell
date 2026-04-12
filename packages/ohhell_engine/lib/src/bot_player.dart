import 'dart:math';

import 'models/card.dart';
import 'models/game_state.dart';

// ---------------------------------------------------------------------------
// Difficulty enum
// ---------------------------------------------------------------------------

/// Difficulty tier for bot players.
enum BotDifficulty {
  /// Random legal bids and plays.
  easy,

  /// Heuristic hand-strength bidding with position and last-bidder awareness.
  medium,

  /// Tracks played cards; leads guaranteed winners; manages trump carefully.
  hard;

  /// Creates a [BotPlayer] for this difficulty.
  ///
  /// [random] is only used by [BotDifficulty.easy].
  BotPlayer createBot([Random? random]) => switch (this) {
        BotDifficulty.easy => RandomBot(random),
        BotDifficulty.medium => const PositionalBot(),
        BotDifficulty.hard => const TrackingBot(),
      };
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Returns the forbidden bid for the last bidder in [state], or `null`.
///
/// In Oh Hell the dealer (last to bid) may not choose a value that would
/// make the total of all bids equal [cardsPerHand].
int? _forbiddenBid(GameState state, String myPlayerId, int cardsPerHand) {
  final others = state.players.where((p) => p.id != myPlayerId);
  if (!others.every((p) => p.bid != null)) return null;
  final total = others.fold<int>(0, (s, p) => s + (p.bid ?? 0));
  final forbidden = cardsPerHand - total;
  return forbidden >= 0 ? forbidden : null;
}

/// Adjusts [desired] to avoid the [forbidden] bid value.
int _avoidForbidden(int desired, int? forbidden, int max) {
  if (forbidden == null || desired != forbidden) return desired;
  if (forbidden < max) return forbidden + 1;
  return (forbidden - 1).clamp(0, max);
}

/// Returns the card currently winning [trick], accounting for trump.
PlayingCard? _currentWinner(Trick trick, Suit? trumpSuit) {
  if (trick.plays.isEmpty) return null;
  final leadSuit = trick.leadSuit;
  PlayingCard? winner;
  for (final play in trick.plays) {
    if (winner == null) {
      winner = play.card;
      continue;
    }
    final card = play.card;
    if (trumpSuit != null && card.suit == trumpSuit) {
      if (winner.suit != trumpSuit || card.rank.value > winner.rank.value) {
        winner = card;
      }
    } else if (card.suit == leadSuit && winner.suit != trumpSuit) {
      if (card.rank.value > winner.rank.value) winner = card;
    }
  }
  return winner;
}

// ---------------------------------------------------------------------------
// BotPlayer interface
// ---------------------------------------------------------------------------

/// Interface for computer-controlled players.
abstract interface class BotPlayer {
  /// Chooses a bid for the current round.
  int chooseBid(GameState state, String myPlayerId);

  /// Chooses a card to play from [legalCards].
  PlayingCard chooseCard(
    GameState state,
    String myPlayerId,
    List<PlayingCard> legalCards,
  );
}

// ---------------------------------------------------------------------------
// Easy: RandomBot
// ---------------------------------------------------------------------------

/// Random legal bids and plays. [BotDifficulty.easy].
class RandomBot implements BotPlayer {
  RandomBot([Random? random]) : _random = random ?? Random();

  final Random _random;

  @override
  int chooseBid(GameState state, String myPlayerId) {
    final round = state.currentRound;
    if (round == null) return 0;
    return _random.nextInt(round.cardsPerHand + 1);
  }

  @override
  PlayingCard chooseCard(
    GameState state,
    String myPlayerId,
    List<PlayingCard> legalCards,
  ) =>
      legalCards[_random.nextInt(legalCards.length)];
}

// ---------------------------------------------------------------------------
// Heuristic (legacy medium — kept for backwards compatibility)
// ---------------------------------------------------------------------------

/// Simple heuristic bot. Prefer [PositionalBot] for the medium tier.
///
/// Bidding: counts high cards (jack+) and mid-trump (9/10).
/// Respects the last-bidder constraint.
/// Playing: plays highest when needing tricks, lowest otherwise.
class HeuristicBot implements BotPlayer {
  const HeuristicBot();

  @override
  int chooseBid(GameState state, String myPlayerId) {
    final player = state.players.firstWhere((p) => p.id == myPlayerId);
    final round = state.currentRound;
    if (round == null) return 0;

    var bid = 0;
    for (final card in player.hand) {
      if (card.rank.value >= Rank.jack.value) {
        bid++;
      } else if (round.trumpSuit != null &&
          card.suit == round.trumpSuit &&
          card.rank.value >= Rank.nine.value) {
        bid++;
      }
    }

    bid = bid.clamp(0, round.cardsPerHand);
    return _avoidForbidden(
      bid,
      _forbiddenBid(state, myPlayerId, round.cardsPerHand),
      round.cardsPerHand,
    );
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
    final sorted = List<PlayingCard>.of(legalCards)
      ..sort((a, b) => a.rank.value.compareTo(b.rank.value));
    return tricksNeeded > 0 ? sorted.last : sorted.first;
  }
}

// ---------------------------------------------------------------------------
// Medium: PositionalBot
// ---------------------------------------------------------------------------

/// Heuristic bot with seat-position and last-bidder awareness.
/// [BotDifficulty.medium].
///
/// Improvements over [HeuristicBot]:
/// - Always respects the dealer (last-bidder) constraint.
/// - When following, plays just above the current winning card
///   instead of always blasting the highest.
/// - Avoids leading trump when shedding tricks.
class PositionalBot implements BotPlayer {
  const PositionalBot();

  @override
  int chooseBid(GameState state, String myPlayerId) {
    final player = state.players.firstWhere((p) => p.id == myPlayerId);
    final round = state.currentRound;
    if (round == null) return 0;

    var bid = 0;
    for (final card in player.hand) {
      if (card.rank.value >= Rank.jack.value) {
        bid++;
      } else if (round.trumpSuit != null &&
          card.suit == round.trumpSuit &&
          card.rank.value >= Rank.nine.value) {
        bid++;
      }
    }

    bid = bid.clamp(0, round.cardsPerHand);
    return _avoidForbidden(
      bid,
      _forbiddenBid(state, myPlayerId, round.cardsPerHand),
      round.cardsPerHand,
    );
  }

  @override
  PlayingCard chooseCard(
    GameState state,
    String myPlayerId,
    List<PlayingCard> legalCards,
  ) {
    final player = state.players.firstWhere((p) => p.id == myPlayerId);
    final round = state.currentRound;
    final bid = player.bid ?? 0;
    final tricksNeeded = bid - player.tricksWon;
    final trumpSuit = round?.trumpSuit;
    final leadSuit = round?.currentTrick.leadSuit;
    final trick = round?.currentTrick;

    final sorted = List<PlayingCard>.of(legalCards)
      ..sort((a, b) => a.rank.value.compareTo(b.rank.value));

    if (tricksNeeded > 0) {
      if (leadSuit == null) {
        // Leading — lead highest non-trump
        final nonTrump = sorted.where((c) => c.suit != trumpSuit).toList();
        return nonTrump.isNotEmpty ? nonTrump.last : sorted.last;
      }

      // Following — play just above the winner when possible
      final inSuit = sorted.where((c) => c.suit == leadSuit).toList();
      if (inSuit.isNotEmpty) {
        final winCard = trick != null ? _currentWinner(trick, trumpSuit) : null;
        final beaters = inSuit
            .where((c) => c.rank.value > (winCard?.rank.value ?? 0))
            .toList();
        return beaters.isNotEmpty ? beaters.first : inSuit.last;
      }

      // Can't follow — trump
      if (trumpSuit != null) {
        final trump = sorted.where((c) => c.suit == trumpSuit).toList();
        if (trump.isNotEmpty) return trump.last;
      }
      return sorted.last;
    } else {
      // Shedding tricks — play low, avoid trump
      if (leadSuit == null) {
        final nonTrump = sorted.where((c) => c.suit != trumpSuit).toList();
        return nonTrump.isNotEmpty ? nonTrump.first : sorted.first;
      }

      final inSuit = sorted.where((c) => c.suit == leadSuit).toList();
      if (inSuit.isNotEmpty) return inSuit.first;

      // Can't follow — discard lowest non-trump
      final nonTrump = sorted.where((c) => c.suit != trumpSuit).toList();
      return nonTrump.isNotEmpty ? nonTrump.first : sorted.first;
    }
  }
}

// ---------------------------------------------------------------------------
// Hard: TrackingBot
// ---------------------------------------------------------------------------

/// Tracks all played cards and leads guaranteed winners first.
/// [BotDifficulty.hard].
///
/// Improvements over [PositionalBot]:
/// - Bidding: aces are certain wins; kings count only when we don't also
///   hold the same-suit ace; adds ruffing potential for void suits.
/// - Playing: identifies cards that are now the highest remaining in their
///   suit and leads those; uses minimum trump to over-trump; discards
///   safely when shedding.
class TrackingBot implements BotPlayer {
  const TrackingBot();

  Set<PlayingCard> _playedCards(GameState state) {
    final result = <PlayingCard>{};
    final round = state.currentRound;
    if (round == null) return result;
    for (final t in round.tricks) {
      for (final p in t.plays) result.add(p.card);
    }
    for (final p in round.currentTrick.plays) result.add(p.card);
    return result;
  }

  bool _isGuaranteedWinner(
    PlayingCard card,
    Set<PlayingCard> played,
  ) {
    for (final rank in Rank.values) {
      if (rank.value <= card.rank.value) continue;
      final higher = PlayingCard(suit: card.suit, rank: rank);
      if (!played.contains(higher)) return false;
    }
    return true;
  }

  @override
  int chooseBid(GameState state, String myPlayerId) {
    final player = state.players.firstWhere((p) => p.id == myPlayerId);
    final round = state.currentRound;
    if (round == null) return 0;

    final trumpSuit = round.trumpSuit;
    var bid = 0;

    for (final card in player.hand) {
      if (card.rank == Rank.ace) {
        bid++;
      } else if (card.rank == Rank.king) {
        // King wins unless we also hold the same-suit ace (ace already counted)
        final sameAce = PlayingCard(suit: card.suit, rank: Rank.ace);
        if (!player.hand.contains(sameAce)) bid++;
      } else if (trumpSuit != null && card.suit == trumpSuit) {
        if (card.rank.value >= Rank.queen.value) bid++;
        if (card.rank.value >= Rank.nine.value &&
            card.rank.value < Rank.queen.value) {
          bid++;
        }
      }
    }

    // Ruffing potential: void non-trump suit while holding trump
    if (trumpSuit != null) {
      final hasTrump = player.hand.any((c) => c.suit == trumpSuit);
      if (hasTrump) {
        for (final suit in Suit.values) {
          if (suit == trumpSuit) continue;
          if (!player.hand.any((c) => c.suit == suit)) bid++;
        }
      }
    }

    bid = bid.clamp(0, round.cardsPerHand);
    return _avoidForbidden(
      bid,
      _forbiddenBid(state, myPlayerId, round.cardsPerHand),
      round.cardsPerHand,
    );
  }

  @override
  PlayingCard chooseCard(
    GameState state,
    String myPlayerId,
    List<PlayingCard> legalCards,
  ) {
    final player = state.players.firstWhere((p) => p.id == myPlayerId);
    final round = state.currentRound;
    final bid = player.bid ?? 0;
    final tricksNeeded = bid - player.tricksWon;
    final trumpSuit = round?.trumpSuit;
    final leadSuit = round?.currentTrick.leadSuit;
    final trick = round?.currentTrick;
    final played = _playedCards(state);

    final sorted = List<PlayingCard>.of(legalCards)
      ..sort((a, b) => a.rank.value.compareTo(b.rank.value));

    if (tricksNeeded > 0) {
      return leadSuit == null
          ? _leadToWin(sorted, trumpSuit, played)
          : _followToWin(sorted, leadSuit, trumpSuit, trick!, played);
    } else {
      return leadSuit == null
          ? _leadToLose(sorted, trumpSuit)
          : _followToLose(sorted, leadSuit, trumpSuit);
    }
  }

  PlayingCard _leadToWin(
    List<PlayingCard> sorted,
    Suit? trumpSuit,
    Set<PlayingCard> played,
  ) {
    // Lead a non-trump guaranteed winner first
    for (final card in sorted.reversed) {
      if (card.suit == trumpSuit) continue;
      if (_isGuaranteedWinner(card, played)) return card;
    }
    // Then a trump guaranteed winner
    for (final card in sorted.reversed) {
      if (card.suit != trumpSuit) continue;
      if (_isGuaranteedWinner(card, played)) return card;
    }
    // No guaranteed winner — lead highest non-trump
    final nonTrump = sorted.where((c) => c.suit != trumpSuit).toList();
    return nonTrump.isNotEmpty ? nonTrump.last : sorted.last;
  }

  PlayingCard _leadToLose(List<PlayingCard> sorted, Suit? trumpSuit) {
    final nonTrump = sorted.where((c) => c.suit != trumpSuit).toList();
    return nonTrump.isNotEmpty ? nonTrump.first : sorted.first;
  }

  PlayingCard _followToWin(
    List<PlayingCard> sorted,
    Suit leadSuit,
    Suit? trumpSuit,
    Trick trick,
    Set<PlayingCard> played,
  ) {
    final inSuit = sorted.where((c) => c.suit == leadSuit).toList();
    if (inSuit.isNotEmpty) {
      // Play minimum card that beats current winner
      final winCard = _currentWinner(trick, trumpSuit);
      final beaters = inSuit
          .where((c) => c.rank.value > (winCard?.rank.value ?? 0))
          .toList();
      return beaters.isNotEmpty ? beaters.first : inSuit.last;
    }

    // Can't follow — over-trump with minimum trump
    if (trumpSuit != null) {
      final trump = sorted.where((c) => c.suit == trumpSuit).toList();
      if (trump.isNotEmpty) {
        final existingTop = trick.plays
            .where((p) => p.card.suit == trumpSuit)
            .fold<int>(0, (m, p) => p.card.rank.value > m ? p.card.rank.value : m);
        final overTrumps =
            trump.where((c) => c.rank.value > existingTop).toList();
        return overTrumps.isNotEmpty ? overTrumps.first : trump.last;
      }
    }

    return sorted.last;
  }

  PlayingCard _followToLose(
    List<PlayingCard> sorted,
    Suit leadSuit,
    Suit? trumpSuit,
  ) {
    final inSuit = sorted.where((c) => c.suit == leadSuit).toList();
    if (inSuit.isNotEmpty) return inSuit.first;
    final nonTrump = sorted.where((c) => c.suit != trumpSuit).toList();
    return nonTrump.isNotEmpty ? nonTrump.first : sorted.first;
  }
}
