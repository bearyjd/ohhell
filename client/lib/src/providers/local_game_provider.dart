import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohhell_engine/ohhell_engine.dart';
import 'package:uuid/uuid.dart';

import '../models/local_game_state.dart';

const _uuid = Uuid();
const _botThinkMs = 800;
const _engine = GameEngine();
const _validator = CardValidator();

class LocalGameNotifier extends StateNotifier<LocalGameState> {
  LocalGameNotifier() : super(const LocalGameState.idle());

  final Map<String, BotPlayer> _bots = {};

  void startGame({
    required String humanName,
    required int botCount,
    required BotDifficulty difficulty,
    required bool strictScoring,
  }) {
    _bots.clear();
    final humanId = _uuid.v4();
    final botIds = List.generate(botCount, (_) => _uuid.v4());

    for (final id in botIds) {
      _bots[id] = difficulty.createBot();
    }

    final players = [
      Player(id: humanId, name: humanName),
      for (var i = 0; i < botCount; i++)
        Player(id: botIds[i], name: _botName(difficulty, i)),
    ];

    final config = GameConfig.defaultFor(players.length).copyWith(
      scoringVariant:
          strictScoring ? ScoringVariant.strict : ScoringVariant.standard,
    );

    var gs = _engine.startGame(players, config);
    gs = _engine.dealRound(gs);

    state = LocalGameState(
      phase: LocalGamePhase.bidding,
      gameState: gs,
      humanPlayerId: humanId,
      botPlayerIds: List.unmodifiable(botIds),
      awaitingBot: false,
    );

    _advanceBotsIfNeeded();
  }

  void humanPlaceBid(int bid) {
    final gs = state.gameState;
    if (gs == null || gs.phase is! Bidding) return;
    final humanId = state.humanPlayerId;
    if (humanId == null) return;

    final round = gs.currentRound;
    if (round == null) return;
    // Verify it's the human's turn
    if (gs.players[round.currentPlayerIndex].id != humanId) return;

    final updated = _engine.placeBid(gs, humanId, bid);
    final newPhase = updated.phase is Playing
        ? LocalGamePhase.playing
        : LocalGamePhase.bidding;
    state = state.copyWith(gameState: updated, phase: newPhase);
    _advanceBotsIfNeeded();
  }

  void humanPlayCard(PlayingCard card) {
    final gs = state.gameState;
    if (gs == null || gs.phase is! Playing) return;
    final humanId = state.humanPlayerId;
    if (humanId == null) return;

    final round = gs.currentRound;
    if (round == null) return;
    if (gs.players[round.currentPlayerIndex].id != humanId) return;

    _doPlayCard(gs, humanId, card);
  }

  void dealNextRound() {
    final gs = state.gameState;
    if (gs == null || gs.phase is! Dealing) return;

    final dealt = _engine.dealRound(gs);
    state = state.copyWith(
      phase: LocalGamePhase.bidding,
      gameState: dealt,
      awaitingBot: false,
    );
    _advanceBotsIfNeeded();
  }

  void reset() {
    _bots.clear();
    state = const LocalGameState.idle();
  }

  /// Returns the legal cards for the human player in the current trick.
  List<PlayingCard> legalCardsForHuman() {
    final gs = state.gameState;
    if (gs == null || gs.phase is! Playing) return const [];
    final humanId = state.humanPlayerId;
    if (humanId == null) return const [];
    final player = gs.players.firstWhere(
      (p) => p.id == humanId,
      orElse: () => const Player(id: '', name: ''),
    );
    if (player.id.isEmpty) return const [];
    final leadSuit = gs.currentRound?.currentTrick.leadSuit;
    return _validator.legalCards(hand: player.hand, leadSuit: leadSuit);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _doPlayCard(GameState gs, String playerId, PlayingCard card) {
    final updated = _engine.playCard(gs, playerId, card);

    if (updated.phase is GameEnd) {
      state = state.copyWith(
        phase: LocalGamePhase.gameOver,
        gameState: updated,
        awaitingBot: false,
      );
      return;
    }

    if (updated.phase is Dealing) {
      // Round ended — engine moved to Dealing for next round
      state = state.copyWith(
        phase: LocalGamePhase.roundEnd,
        gameState: updated,
        awaitingBot: false,
      );
      return;
    }

    state = state.copyWith(
      gameState: updated,
      phase: LocalGamePhase.playing,
      awaitingBot: false,
    );
    _advanceBotsIfNeeded();
  }

  void _advanceBotsIfNeeded() {
    final gs = state.gameState;
    if (gs == null) return;

    final currentPlayerId = _currentActorId(gs);
    if (currentPlayerId == null) return;
    if (!state.botPlayerIds.contains(currentPlayerId)) return;

    state = state.copyWith(awaitingBot: true);
    Future.delayed(const Duration(milliseconds: _botThinkMs), () {
      if (!mounted) return;
      _botAct(currentPlayerId);
    });
  }

  void _botAct(String botId) {
    final gs = state.gameState;
    if (gs == null) return;
    final bot = _bots[botId];
    if (bot == null) return;

    if (gs.phase is Bidding) {
      final bid = bot.chooseBid(gs, botId);
      final updated = _engine.placeBid(gs, botId, bid);
      final newPhase = updated.phase is Playing
          ? LocalGamePhase.playing
          : LocalGamePhase.bidding;
      state = state.copyWith(
        gameState: updated,
        phase: newPhase,
        awaitingBot: false,
      );
      _advanceBotsIfNeeded();
    } else if (gs.phase is Playing) {
      final round = gs.currentRound;
      if (round == null) return;
      final player = gs.players.firstWhere((p) => p.id == botId);
      final leadSuit = round.currentTrick.leadSuit;
      final legal =
          _validator.legalCards(hand: player.hand, leadSuit: leadSuit);
      if (legal.isEmpty) return;
      final card = bot.chooseCard(gs, botId, legal);
      _doPlayCard(gs, botId, card);
    }
  }

  String? _currentActorId(GameState gs) {
    if (gs.phase is Bidding || gs.phase is Playing) {
      final round = gs.currentRound;
      if (round == null) return null;
      final idx = round.currentPlayerIndex;
      if (idx < 0 || idx >= gs.players.length) return null;
      return gs.players[idx].id;
    }
    return null;
  }

  String _botName(BotDifficulty d, int index) {
    final suffix = index > 0 ? ' ${index + 1}' : '';
    return switch (d) {
      BotDifficulty.easy => 'Easy Bot$suffix',
      BotDifficulty.medium => 'Bot$suffix',
      BotDifficulty.hard => 'Hard Bot$suffix',
    };
  }
}

final localGameProvider =
    StateNotifierProvider<LocalGameNotifier, LocalGameState>(
  (_) => LocalGameNotifier(),
);
