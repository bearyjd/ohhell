import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohhell_engine/ohhell_engine.dart';

/// Immutable state for the single-phone scorekeeper.
class ScorekeeperState {
  const ScorekeeperState({
    this.playerNames = const [],
    this.roundSchedule = const [],
    this.currentRoundIndex = 0,
    this.bids = const [],
    this.tricks = const [],
    this.currentRoundBids = const {},
    this.currentRoundTricks = const {},
  });

  /// Names of the players (3–7).
  final List<String> playerNames;

  /// Cards dealt each round (auto-calculated from player count).
  final List<int> roundSchedule;

  /// Index of the round currently being played.
  final int currentRoundIndex;

  /// Committed bids indexed by round: `bids[roundIndex][playerName]`.
  final List<Map<String, int>> bids;

  /// Committed tricks indexed by round: `tricks[roundIndex][playerName]`.
  final List<Map<String, int>> tricks;

  /// Pending bids being entered for the current round (not yet committed).
  final Map<String, int> currentRoundBids;

  /// Pending tricks being entered for the current round (not yet committed).
  final Map<String, int> currentRoundTricks;

  ScorekeeperState copyWith({
    List<String>? playerNames,
    List<int>? roundSchedule,
    int? currentRoundIndex,
    List<Map<String, int>>? bids,
    List<Map<String, int>>? tricks,
    Map<String, int>? currentRoundBids,
    Map<String, int>? currentRoundTricks,
  }) {
    return ScorekeeperState(
      playerNames: playerNames ?? this.playerNames,
      roundSchedule: roundSchedule ?? this.roundSchedule,
      currentRoundIndex: currentRoundIndex ?? this.currentRoundIndex,
      bids: bids ?? this.bids,
      tricks: tricks ?? this.tricks,
      currentRoundBids: currentRoundBids ?? this.currentRoundBids,
      currentRoundTricks: currentRoundTricks ?? this.currentRoundTricks,
    );
  }
}

/// Manages scorekeeper state for a physical Oh Hell game.
class ScorekeeperNotifier extends StateNotifier<ScorekeeperState> {
  ScorekeeperNotifier() : super(const ScorekeeperState());

  static const _calculator = ScoreCalculator();

  // ── Setup ──────────────────────────────────────────────────────────────────

  /// Starts a new game.
  ///
  /// Throws [ArgumentError] if [playerNames] has fewer than 3 or more than 7
  /// entries (delegated to [GameConfig.defaultFor]).
  void startGame(List<String> playerNames) {
    final config = GameConfig.defaultFor(playerNames.length);
    state = ScorekeeperState(
      playerNames: List.unmodifiable(playerNames),
      roundSchedule: config.roundSchedule,
    );
  }

  // ── Round entry ────────────────────────────────────────────────────────────

  /// Records a bid for [playerName] in the current round.
  void setBid(String playerName, int bid) {
    state = state.copyWith(
      currentRoundBids: {...state.currentRoundBids, playerName: bid},
    );
  }

  /// Records tricks won by [playerName] in the current round.
  void setTricks(String playerName, int tricks) {
    state = state.copyWith(
      currentRoundTricks: {...state.currentRoundTricks, playerName: tricks},
    );
  }

  /// Commits the current round's bids and tricks, advances to the next round.
  ///
  /// Throws [StateError] if the sum of all entered tricks does not equal the
  /// number of cards dealt this round.
  void endRound() {
    final cardsPerHand = state.roundSchedule[state.currentRoundIndex];
    final tricksSum =
        state.currentRoundTricks.values.fold(0, (a, b) => a + b);
    if (tricksSum != cardsPerHand) {
      throw StateError(
        'Tricks total ($tricksSum) must equal cards per hand ($cardsPerHand).',
      );
    }

    state = state.copyWith(
      bids: [
        ...state.bids,
        Map.unmodifiable(state.currentRoundBids),
      ],
      tricks: [
        ...state.tricks,
        Map.unmodifiable(state.currentRoundTricks),
      ],
      currentRoundIndex: state.currentRoundIndex + 1,
      currentRoundBids: const {},
      currentRoundTricks: const {},
    );
  }

  // ── Derived values ─────────────────────────────────────────────────────────

  /// Score for [playerName] in the completed round at [roundIndex].
  int roundScore(int roundIndex, String playerName) {
    final scores = _calculator.calculateRoundScores(
      bids: state.bids[roundIndex],
      tricksWon: state.tricks[roundIndex],
      variant: ScoringVariant.standard,
    );
    return scores[playerName] ?? 0;
  }

  /// Running totals for every player across all completed rounds.
  Map<String, int> get runningTotals {
    final totals = <String, int>{
      for (final name in state.playerNames) name: 0,
    };
    for (var i = 0; i < state.bids.length; i++) {
      final scores = _calculator.calculateRoundScores(
        bids: state.bids[i],
        tricksWon: state.tricks[i],
        variant: ScoringVariant.standard,
      );
      for (final name in state.playerNames) {
        totals[name] = (totals[name] ?? 0) + (scores[name] ?? 0);
      }
    }
    return Map.unmodifiable(totals);
  }

  /// Whether all rounds in the schedule have been completed.
  bool get isGameOver =>
      state.currentRoundIndex >= state.roundSchedule.length;

  /// Player with the highest running total; `null` before any round completes.
  String? get winner {
    if (state.bids.isEmpty) return null;
    final totals = runningTotals;
    return totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ── Export ─────────────────────────────────────────────────────────────────

  /// Generates a plain-text score sheet suitable for sharing.
  String exportText() {
    final buf = StringBuffer();
    final names = state.playerNames;
    final now = DateTime.now();
    final colW = 7;

    buf.writeln(
      '🃏 Oh Hell — ${now.day} ${_monthName(now.month)} ${now.year}',
    );
    buf.writeln('Players: ${names.join(', ')}');
    buf.writeln();

    // Header row
    buf.write('       ');
    for (final name in names) {
      final label = name.length > colW ? name.substring(0, colW) : name;
      buf.write(label.padLeft(colW));
    }
    buf.writeln();

    // One row per completed round
    for (var i = 0; i < state.bids.length; i++) {
      buf.write('Rnd ${i + 1}:'.padRight(7));
      for (final name in names) {
        buf.write(roundScore(i, name).toString().padLeft(colW));
      }
      buf.writeln();
    }

    // Totals row
    buf.write('TOTAL: ');
    final totals = runningTotals;
    for (final name in names) {
      buf.write((totals[name] ?? 0).toString().padLeft(colW));
    }
    buf.writeln();
    buf.writeln();

    if (isGameOver && winner != null) {
      buf.writeln('👑 $winner wins!');
    }
    buf.writeln('Generated by Oh Hell app');

    return buf.toString();
  }

  static String _monthName(int month) {
    const months = [
      '',
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month];
  }
}

/// Provider for the scorekeeper feature.
final scorekeeperProvider =
    StateNotifierProvider<ScorekeeperNotifier, ScorekeeperState>(
  (ref) => ScorekeeperNotifier(),
);
