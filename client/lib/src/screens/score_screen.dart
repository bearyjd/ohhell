import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/providers/game_provider.dart';
import 'package:ohhell_client/src/providers/session_provider.dart';
import 'package:ohhell_client/src/providers/ws_provider.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';
import 'package:ohhell_protocol/ohhell_protocol.dart';

class ScoreScreen extends ConsumerWidget {
  const ScoreScreen({required this.roomCode, super.key});

  final String roomCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final session = ref.watch(sessionProvider);
    final players = gameState?.players ?? <PlayerDto>[];
    final sorted = [...players]
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    final isGameEnd = gameState?.phase == 'game_end';
    final winnerId = gameState?.winnerId;
    final winnerName = winnerId != null
        ? players
                .where((p) => p.id == winnerId)
                .firstOrNull
                ?.name ??
            winnerId
        : null;

    ref.listen(gameStateProvider, (prev, next) {
      if (next == null) return;
      final phase = next.phase;
      if (phase == 'dealing' ||
          phase == 'bidding' ||
          phase == 'playing') {
        if (context.mounted) {
          context.go('/game/$roomCode');
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Scores \u2014 $roomCode'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/game/$roomCode'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isGameEnd && winnerName != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.amber.withAlpha(30),
                      AppColors.amber.withAlpha(80),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold),
                ),
                child: Column(
                  children: [
                    const Text(
                      '🏆',
                      style: TextStyle(fontSize: 32),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$winnerName wins!',
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(
                            color: AppColors.gold,
                            fontSize: 28,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Leaderboard',
              style: Theme.of(context).textTheme.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const _ScoreTableHeader(),
            const Divider(color: AppColors.gold),
            Expanded(
              child: ListView.builder(
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  return _ScoreRow(
                    rank: index + 1,
                    player: sorted[index],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: session.isHost
                  ? () => ref
                      .read(wsProvider.notifier)
                      .send(const StartGameMessage())
                  : null,
              child: Text(
                isGameEnd ? 'New Game' : 'Next Round',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreTableHeader extends StatelessWidget {
  const _ScoreTableHeader();

  static const _headerStyle = TextStyle(
    color: AppColors.gold,
    fontWeight: FontWeight.bold,
    fontSize: 12,
  );

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding:
          EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('#', style: _headerStyle),
          ),
          Expanded(
            flex: 3,
            child: Text('Player', style: _headerStyle),
          ),
          Expanded(
            child: Text(
              'Bid',
              style: _headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Taken',
              style: _headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Score',
              style: _headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.rank, required this.player});

  final int rank;
  final PlayerDto player;

  @override
  Widget build(BuildContext context) {
    final isFirst = rank == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 4,
      ),
      decoration: BoxDecoration(
        color: isFirst
            ? AppColors.gold.withAlpha(26)
            : const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(8),
        border: isFirst
            ? Border.all(color: AppColors.gold.withAlpha(128))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rank',
              style: TextStyle(
                color: isFirst
                    ? AppColors.gold
                    : AppColors.textOnDark,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              player.name,
              style: const TextStyle(
                color: AppColors.textOnDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${player.bid ?? '-'}',
              style: const TextStyle(
                color: AppColors.textOnDark,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              '${player.tricksWon}',
              style: const TextStyle(
                color: AppColors.textOnDark,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              '${player.totalScore}',
              style: TextStyle(
                color: isFirst
                    ? AppColors.gold
                    : AppColors.textOnDark,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
