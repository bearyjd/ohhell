import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohhell_client/src/providers/local_game_provider.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';

class LocalScoresScreen extends ConsumerWidget {
  const LocalScoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localState = ref.watch(localGameProvider);
    final gs = localState.gameState;

    if (gs == null) {
      return const Scaffold(
        body: Center(child: Text('No game data')),
      );
    }

    final sorted = [...gs.players]
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final winner = sorted.first;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        title: const Text('Final Scores'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.amber.withAlpha(30),
                    AppColors.amber.withAlpha(80),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 32)),
                  Text(
                    winner.name,
                    style: const TextStyle(
                      color: AppColors.amber,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${winner.totalScore} points',
                    style: const TextStyle(color: AppColors.textOnDark),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < sorted.length; i++)
                  ListTile(
                    leading: Text(
                      '${i + 1}.',
                      style: TextStyle(
                        color: i == 0
                            ? AppColors.amber
                            : AppColors.textOnDark,
                      ),
                    ),
                    title: Text(
                      sorted[i].name,
                      style: const TextStyle(color: AppColors.textOnDark),
                    ),
                    trailing: Text(
                      '${sorted[i].totalScore}',
                      style: TextStyle(
                        color: i == 0
                            ? AppColors.amber
                            : AppColors.textOnDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(localGameProvider.notifier).reset();
                  context.go('/home');
                },
                child: const Text('Back to Home'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
