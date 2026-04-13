import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/providers/scorekeeper_provider.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';

class ScorerTricksScreen extends ConsumerWidget {
  const ScorerTricksScreen({super.key, required this.round});

  final int round;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scorekeeperProvider);
    final notifier = ref.read(scorekeeperProvider.notifier);

    if (state.playerNames.isEmpty ||
        round >= state.roundSchedule.length) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final cardsPerHand = state.roundSchedule[round];
    final tricksSum =
        state.currentRoundTricks.values.fold(0, (a, b) => a + b);
    final isValid = tricksSum == cardsPerHand;

    return Scaffold(
      appBar: AppBar(
        title: Text('Round ${round + 1} · Tricks'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/scorer/scores'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Tricks total indicator ───────────────────────────────────
            Container(
              color: isValid
                  ? Colors.green.shade800
                  : const Color(0xFF154A19),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isValid ? Icons.check_circle : Icons.warning_amber,
                    color: isValid ? Colors.greenAccent : AppColors.gold,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tricks: $tricksSum / $cardsPerHand',
                    style: TextStyle(
                      color: isValid
                          ? Colors.greenAccent
                          : AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // ── Tricks entry rows ────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.playerNames.length,
                itemBuilder: (context, i) {
                  final name = state.playerNames[i];
                  final tricks = state.currentRoundTricks[name] ?? 0;
                  final bid = state.currentRoundBids[name] ?? 0;

                  return Card(
                    color: const Color(0xFF2E7D32),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: AppColors.textOnDark,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Bid: $bid',
                                  style: TextStyle(
                                    color: AppColors.textOnDark
                                        .withAlpha(180),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: tricks > 0
                                ? () => notifier.setTricks(
                                    name, tricks - 1)
                                : null,
                            icon: const Icon(
                                Icons.remove_circle_outline),
                            color: AppColors.gold,
                          ),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '$tricks',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: tricks < cardsPerHand
                                ? () => notifier.setTricks(
                                    name, tricks + 1)
                                : null,
                            icon:
                                const Icon(Icons.add_circle_outline),
                            color: AppColors.gold,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── End Round button (disabled until valid) ──────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                key: const Key('end_round_button'),
                onPressed: isValid
                    ? () {
                        notifier.endRound();
                        context.go('/scorer/scores');
                      }
                    : null,
                icon: const Icon(Icons.check),
                label: const Text('End Round'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
