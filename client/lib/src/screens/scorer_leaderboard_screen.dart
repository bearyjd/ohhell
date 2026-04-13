import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/providers/scorekeeper_provider.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';

class ScorerLeaderboardScreen extends ConsumerWidget {
  const ScorerLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scorekeeperProvider);
    final notifier = ref.read(scorekeeperProvider.notifier);

    if (state.playerNames.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final totals = notifier.runningTotals;
    final isGameOver = notifier.isGameOver;
    final hasPendingBids = state.currentRoundBids.isNotEmpty;
    final roundIndex = state.currentRoundIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(isGameOver ? 'Final Scores' : 'Scores'),
        leading: const SizedBox.shrink(),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share scores',
            onPressed: () => _share(notifier),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Score table ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _ScoreTable(
                  state: state,
                  notifier: notifier,
                  totals: totals,
                ),
              ),
            ),

            // ── Action area ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isGameOver) ...[
                    // Game over: show winner
                    if (notifier.winner != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF154A19),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.gold),
                        ),
                        child: Text(
                          '👑 ${notifier.winner} wins!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: () => _share(notifier),
                      icon: const Icon(Icons.share),
                      label: const Text('Share Results'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          context.go('/scorer/setup'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        side: const BorderSide(
                            color: AppColors.gold),
                      ),
                      child: const Text('New Game'),
                    ),
                  ] else if (hasPendingBids) ...[
                    // Bids locked, need tricks
                    ElevatedButton.icon(
                      onPressed: () => context.go(
                          '/scorer/tricks/$roundIndex'),
                      icon: const Icon(Icons.casino),
                      label: const Text('Enter Tricks'),
                    ),
                  ] else ...[
                    // Ready for next round bidding
                    ElevatedButton.icon(
                      onPressed: () => context.go(
                          '/scorer/bid/$roundIndex'),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        state.bids.isEmpty
                            ? 'Start Round 1'
                            : 'Next Round (${roundIndex + 1})',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(ScorekeeperNotifier notifier) async {
    final text = notifier.exportText();
    await Share.share(text);
  }
}

// ── Score table widget ─────────────────────────────────────────────────────

class _ScoreTable extends StatelessWidget {
  const _ScoreTable({
    required this.state,
    required this.notifier,
    required this.totals,
  });

  final ScorekeeperState state;
  final ScorekeeperNotifier notifier;
  final Map<String, int> totals;

  @override
  Widget build(BuildContext context) {
    final names = state.playerNames;

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder.all(
        color: AppColors.gold.withAlpha(60),
        borderRadius: BorderRadius.circular(4),
      ),
      children: [
        // Header row
        TableRow(
          decoration: const BoxDecoration(
            color: Color(0xFF154A19),
          ),
          children: [
            _cell('', isHeader: true),
            for (final name in names)
              _cell(name, isHeader: true),
          ],
        ),

        // Round rows
        for (var i = 0; i < state.bids.length; i++)
          TableRow(
            decoration: BoxDecoration(
              color: i.isOdd
                  ? const Color(0xFF245C27)
                  : const Color(0xFF2E7D32),
            ),
            children: [
              _cell('Rnd ${i + 1}', isLabel: true),
              for (final name in names)
                _scoreCell(
                  score: notifier.roundScore(i, name),
                  isExact: (state.bids[i][name] ?? -1) ==
                      (state.tricks[i][name] ?? -2),
                ),
            ],
          ),

        // Totals row
        TableRow(
          decoration: const BoxDecoration(
            color: Color(0xFF154A19),
          ),
          children: [
            _cell('TOTAL', isHeader: true),
            for (final name in names)
              _cell(
                '${totals[name] ?? 0}',
                isHeader: true,
                color: AppColors.gold,
              ),
          ],
        ),
      ],
    );
  }

  static Widget _cell(
    String text, {
    bool isHeader = false,
    bool isLabel = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color ??
              (isHeader || isLabel
                  ? AppColors.gold
                  : AppColors.textOnDark),
          fontWeight: isHeader
              ? FontWeight.bold
              : FontWeight.normal,
          fontSize: isHeader ? 14 : 13,
        ),
      ),
    );
  }

  static Widget _scoreCell({
    required int score,
    required bool isExact,
  }) {
    return Container(
      color: isExact ? Colors.green.withAlpha(60) : null,
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 8),
      child: Text(
        '$score',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isExact ? Colors.greenAccent : AppColors.textOnDark,
          fontWeight:
              isExact ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }
}
