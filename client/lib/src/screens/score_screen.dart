import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';

class ScoreScreen extends StatelessWidget {
  const ScoreScreen({required this.roomCode, super.key});

  final String roomCode;

  static const _dummyScores = [
    (name: 'Alice', score: 47, bid: 2, taken: 2, rounds: 5),
    (name: 'Bob', score: 31, bid: 1, taken: 3, rounds: 5),
    (name: 'Charlie', score: 38, bid: 3, taken: 3, rounds: 5),
  ];

  @override
  Widget build(BuildContext context) {
    final sorted = [..._dummyScores]
      ..sort((a, b) => b.score.compareTo(a.score));

    return Scaffold(
      appBar: AppBar(
        title: Text('Scores — $roomCode'),
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
            Text(
              'Leaderboard',
              style: Theme.of(context).textTheme.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _ScoreTableHeader(),
            const Divider(color: AppColors.gold),
            Expanded(
              child: ListView.builder(
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  return _ScoreRow(
                    rank: index + 1,
                    entry: sorted[index],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/lobby/$roomCode'),
              child: const Text('New Round'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('#', style: _headerStyle)),
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

  static const _headerStyle = TextStyle(
    color: AppColors.gold,
    fontWeight: FontWeight.bold,
    fontSize: 12,
  );
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.rank, required this.entry});

  final int rank;
  final ({String name, int score, int bid, int taken, int rounds}) entry;

  @override
  Widget build(BuildContext context) {
    final isFirst = rank == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
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
                color: isFirst ? AppColors.gold : AppColors.textOnDark,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (isFirst)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Text('🏆', style: TextStyle(fontSize: 14)),
                  ),
                Text(
                  entry.name,
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '${entry.bid}',
              style: const TextStyle(color: AppColors.textOnDark),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              '${entry.taken}',
              style: const TextStyle(color: AppColors.textOnDark),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              '${entry.score}',
              style: TextStyle(
                color: isFirst ? AppColors.gold : AppColors.textOnDark,
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
