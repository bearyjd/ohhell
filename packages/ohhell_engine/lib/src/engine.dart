import 'dart:math';

import 'card_validator.dart';
import 'exceptions.dart';
import 'models/card.dart';
import 'models/game_config.dart';
import 'models/game_state.dart';
import 'score_calculator.dart';

/// The core game engine. All methods return new immutable state.
class GameEngine {
  const GameEngine({
    CardValidator validator = const CardValidator(),
    ScoreCalculator scoreCalculator = const ScoreCalculator(),
  }) : _validator = validator,
       _scoreCalculator = scoreCalculator;

  final CardValidator _validator;
  final ScoreCalculator _scoreCalculator;

  /// Starts a new game with the given players and config.
  GameState startGame(List<Player> players, GameConfig config) {
    if (players.length < 3 || players.length > 7) {
      throw InvalidGameStateException(
        'Player count must be 3-7, got ${players.length}',
      );
    }
    if (config.roundSchedule.isEmpty) {
      throw InvalidGameStateException('Round schedule must not be empty');
    }

    final resetPlayers = [
      for (final p in players)
        p.copyWith(
          hand: const [],
          bid: () => null,
          tricksWon: 0,
          totalScore: 0,
        ),
    ];

    return GameState(
      phase: const Dealing(),
      players: List.unmodifiable(resetPlayers),
      config: config,
    );
  }

  /// Deals cards for the next round.
  GameState dealRound(GameState state, {Random? random}) {
    if (state.phase is! Dealing) {
      throw InvalidGameStateException(
        'Cannot deal: game is not in dealing phase',
      );
    }

    final roundIndex = state.rounds.length;
    if (roundIndex >= state.config.roundSchedule.length) {
      throw InvalidGameStateException('No more rounds to deal');
    }

    final cardsPerHand = state.config.roundSchedule[roundIndex];
    final deck = Deck.standard().shuffle(random);
    final result = deck.deal(
      numPlayers: state.players.length,
      cardsPerHand: cardsPerHand,
    );

    // Trump card is the first remaining card (if any)
    final Suit? trumpSuit;
    if (result.remaining.isNotEmpty) {
      trumpSuit = result.remaining.first.suit;
    } else {
      trumpSuit = null;
    }

    final updatedPlayers = <Player>[
      for (var i = 0; i < state.players.length; i++)
        state.players[i].copyWith(
          hand: List.unmodifiable(result.hands[i]),
          bid: () => null,
          tricksWon: 0,
        ),
    ];

    final round = RoundState(
      roundNumber: roundIndex + 1,
      cardsPerHand: cardsPerHand,
      trumpSuit: trumpSuit,
      currentTrick: Trick(trumpSuit: trumpSuit),
    );

    return state.copyWith(
      phase: const Bidding(),
      players: List.unmodifiable(updatedPlayers),
      currentRound: () => round,
    );
  }

  /// Places a bid for the given player.
  GameState placeBid(GameState state, String playerId, int bid) {
    if (state.phase is! Bidding) {
      throw IllegalMoveException('Cannot bid: not in bidding phase');
    }

    final round = state.currentRound;
    if (round == null) {
      throw InvalidGameStateException('No current round');
    }

    final expectedPlayer = state.players[round.currentPlayerIndex];
    if (expectedPlayer.id != playerId) {
      throw IllegalMoveException(
        'Not your turn to bid. Expected ${expectedPlayer.id}',
      );
    }

    if (bid < 0) {
      throw IllegalMoveException('Bid must be non-negative');
    }

    final newBids = Map<String, int>.of(round.bids);
    newBids[playerId] = bid;

    final nextPlayerIndex = round.currentPlayerIndex + 1;
    final allBidsPlaced = nextPlayerIndex >= state.players.length;

    final newRound = round.copyWith(
      bids: Map.unmodifiable(newBids),
      currentPlayerIndex: allBidsPlaced ? 0 : nextPlayerIndex,
    );

    return state.copyWith(
      phase: allBidsPlaced ? const Playing() : null,
      currentRound: () => newRound,
    );
  }

  /// Plays a card for the given player.
  GameState playCard(GameState state, String playerId, PlayingCard card) {
    if (state.phase is! Playing) {
      throw IllegalMoveException('Cannot play card: not in playing phase');
    }

    final round = state.currentRound;
    if (round == null) {
      throw InvalidGameStateException('No current round');
    }

    final playerIndex = round.currentPlayerIndex;
    final player = state.players[playerIndex];
    if (player.id != playerId) {
      throw IllegalMoveException('Not your turn. Expected ${player.id}');
    }

    if (!player.hand.contains(card)) {
      throw IllegalMoveException('Card not in hand: $card');
    }

    final leadSuit = round.currentTrick.leadSuit;
    if (!_validator.canPlay(
      hand: player.hand,
      card: card,
      leadSuit: leadSuit,
    )) {
      throw IllegalMoveException('Must follow suit: $leadSuit');
    }

    // Determine lead suit for this trick
    final newLeadSuit = leadSuit ?? card.suit;

    final newPlays = [
      ...round.currentTrick.plays,
      TrickPlay(playerId: playerId, card: card),
    ];

    // Remove card from player's hand
    final newHand = player.hand.where((c) => c != card).toList();
    final updatedPlayer = player.copyWith(hand: List.unmodifiable(newHand));

    var updatedPlayers = [
      for (var i = 0; i < state.players.length; i++)
        if (i == playerIndex) updatedPlayer else state.players[i],
    ];

    final trickComplete = newPlays.length == state.players.length;

    if (!trickComplete) {
      // Trick not complete — advance to next player
      final newTrick = round.currentTrick.copyWith(
        plays: List.unmodifiable(newPlays),
        leadSuit: () => newLeadSuit,
      );

      final newRound = round.copyWith(
        currentTrick: newTrick,
        currentPlayerIndex: (playerIndex + 1) % state.players.length,
      );

      return state.copyWith(
        players: List.unmodifiable(updatedPlayers),
        currentRound: () => newRound,
      );
    }

    // Trick complete — evaluate winner
    final completedTrick = Trick(
      plays: List.unmodifiable(newPlays),
      leadSuit: newLeadSuit,
      trumpSuit: round.trumpSuit,
    );

    final winnerId = evaluateTrick(completedTrick, round.trumpSuit);
    final winnerIndex = updatedPlayers.indexWhere((p) => p.id == winnerId);

    updatedPlayers = [
      for (var i = 0; i < updatedPlayers.length; i++)
        if (i == winnerIndex)
          updatedPlayers[i].copyWith(tricksWon: updatedPlayers[i].tricksWon + 1)
        else
          updatedPlayers[i],
    ];

    final completedTricks = [...round.tricks, completedTrick];
    final roundComplete = completedTricks.length == round.cardsPerHand;

    if (!roundComplete) {
      // More tricks to play — winner leads next trick
      final newRound = round.copyWith(
        tricks: List.unmodifiable(completedTricks),
        currentTrick: Trick(trumpSuit: round.trumpSuit),
        currentPlayerIndex: winnerIndex,
      );

      return state.copyWith(
        players: List.unmodifiable(updatedPlayers),
        currentRound: () => newRound,
      );
    }

    // Round complete — score it
    return _endRound(
      state.copyWith(
        players: List.unmodifiable(updatedPlayers),
        currentRound: () => round.copyWith(
          tricks: List.unmodifiable(completedTricks),
          currentTrick: completedTrick,
        ),
      ),
    );
  }

  /// Evaluates a completed trick to determine the winner.
  String evaluateTrick(Trick trick, Suit? trumpSuit) {
    if (trick.plays.isEmpty) {
      throw InvalidGameStateException('Cannot evaluate empty trick');
    }

    final leadSuit = trick.plays.first.card.suit;
    TrickPlay winner = trick.plays.first;

    for (final play in trick.plays.skip(1)) {
      final currentWinnerIsTrump =
          trumpSuit != null && winner.card.suit == trumpSuit;
      final candidateIsTrump = trumpSuit != null && play.card.suit == trumpSuit;

      if (candidateIsTrump && !currentWinnerIsTrump) {
        // Trump beats non-trump
        winner = play;
      } else if (candidateIsTrump && currentWinnerIsTrump) {
        // Both trump — higher rank wins
        if (play.card.rank.value > winner.card.rank.value) {
          winner = play;
        }
      } else if (!candidateIsTrump && !currentWinnerIsTrump) {
        // Neither trump — must be lead suit and higher rank
        if (play.card.suit == leadSuit &&
            winner.card.suit == leadSuit &&
            play.card.rank.value > winner.card.rank.value) {
          winner = play;
        } else if (play.card.suit == leadSuit && winner.card.suit != leadSuit) {
          winner = play;
        }
      }
      // Non-trump doesn't beat trump — skip
    }

    return winner.playerId;
  }

  /// Ends the current round, computes scores, and advances state.
  GameState _endRound(GameState state) {
    final round = state.currentRound;
    if (round == null) {
      throw InvalidGameStateException('No current round to end');
    }

    final tricksWon = <String, int>{
      for (final p in state.players) p.id: p.tricksWon,
    };

    final roundScores = _scoreCalculator.calculateRoundScores(
      bids: round.bids,
      tricksWon: tricksWon,
      variant: state.config.scoringVariant,
    );

    final updatedPlayers = [
      for (final p in state.players)
        p.copyWith(totalScore: p.totalScore + (roundScores[p.id] ?? 0)),
    ];

    final completedRounds = [...state.rounds, round];
    final hasMoreRounds =
        completedRounds.length < state.config.roundSchedule.length;

    if (hasMoreRounds) {
      return state.copyWith(
        phase: const Dealing(),
        players: List.unmodifiable(updatedPlayers),
        rounds: List.unmodifiable(completedRounds),
        currentRound: () => null,
      );
    }

    // Game over — find winner
    var maxScore = updatedPlayers.first.totalScore;
    var winnerPlayerId = updatedPlayers.first.id;
    for (final p in updatedPlayers.skip(1)) {
      if (p.totalScore > maxScore) {
        maxScore = p.totalScore;
        winnerPlayerId = p.id;
      }
    }

    return state.copyWith(
      phase: const GameEnd(),
      players: List.unmodifiable(updatedPlayers),
      rounds: List.unmodifiable(completedRounds),
      currentRound: () => null,
      winnerId: () => winnerPlayerId,
    );
  }
}
