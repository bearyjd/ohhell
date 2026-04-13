import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/providers/scorekeeper_provider.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';

class ScorerBiddingScreen extends ConsumerWidget {
  const ScorerBiddingScreen({super.key, required this.round});

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
    final totals = notifier.runningTotals;

    return Scaffold(
      appBar: AppBar(
        title: Text('Round ${round + 1} · $cardsPerHand card'
            '${cardsPerHand == 1 ? '' : 's'}'),
        leading: const SizedBox.shrink(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Bid entry rows ───────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.playerNames.length,
                itemBuilder: (context, i) {
                  final name = state.playerNames[i];
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
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: AppColors.textOnDark,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: bid > 0
                                ? () => notifier.setBid(name, bid - 1)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            color: AppColors.gold,
                          ),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '$bid',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: bid < cardsPerHand
                                ? () => notifier.setBid(name, bid + 1)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                            color: AppColors.gold,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Mini running totals ──────────────────────────────────────
            if (state.bids.isNotEmpty)
              Container(
                color: const Color(0xFF154A19),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: state.playerNames.map((name) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${totals[name] ?? 0}',
                              style: const TextStyle(
                                color: AppColors.textOnDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            // ── Lock Bids button ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => context.go('/scorer/scores'),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Lock Bids'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
