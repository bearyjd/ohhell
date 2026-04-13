import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/providers/scorekeeper_provider.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';

class ScorerSetupScreen extends ConsumerStatefulWidget {
  const ScorerSetupScreen({super.key});

  @override
  ConsumerState<ScorerSetupScreen> createState() => _ScorerSetupScreenState();
}

class _ScorerSetupScreenState extends ConsumerState<ScorerSetupScreen> {
  int _playerCount = 4;
  final _nameControllers = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _playerCount; i++) {
      _nameControllers.add(TextEditingController(text: 'Player ${i + 1}'));
    }
  }

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _increment() {
    if (_playerCount >= 7) return;
    setState(() {
      _playerCount++;
      _nameControllers
          .add(TextEditingController(text: 'Player $_playerCount'));
    });
  }

  void _decrement() {
    if (_playerCount <= 3) return;
    setState(() {
      _nameControllers.last.dispose();
      _nameControllers.removeLast();
      _playerCount--;
    });
  }

  /// Round schedule preview (mirrors GameConfig.defaultFor logic).
  List<int> _schedule() {
    final maxCards = (52 - 1) ~/ _playerCount;
    return [
      for (var i = 1; i <= maxCards; i++) i,
      for (var i = maxCards - 1; i >= 1; i--) i,
    ];
  }

  void _startGame() {
    final names = List.generate(_playerCount, (i) {
      final text = _nameControllers[i].text.trim();
      return text.isEmpty ? 'Player ${i + 1}' : text;
    });
    ref.read(scorekeeperProvider.notifier).startGame(names);
    context.go('/scorer/bid/0');
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _schedule();
    final maxCards = schedule.reduce((a, b) => a > b ? a : b);
    final scheduleLabel =
        '${schedule.length} rounds · 1 → $maxCards → 1';

    return Scaffold(
      appBar: AppBar(title: const Text('Scorekeeper Setup')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Player count stepper ───────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    key: const Key('decrement_players'),
                    onPressed: _playerCount > 3 ? _decrement : null,
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: AppColors.gold,
                    ),
                    iconSize: 36,
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        Text(
                          '$_playerCount',
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(color: AppColors.gold),
                        ),
                        const Text(
                          'Players',
                          style: TextStyle(
                              color: AppColors.textOnDark),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('increment_players'),
                    onPressed: _playerCount < 7 ? _increment : null,
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: AppColors.gold,
                    ),
                    iconSize: 36,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Round schedule preview ─────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF154A19),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  scheduleLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Player name fields ─────────────────────────────────────
              for (var i = 0; i < _playerCount; i++) ...[
                TextField(
                  controller: _nameControllers[i],
                  style: const TextStyle(color: AppColors.textOnDark),
                  decoration: InputDecoration(
                    labelText: 'Player ${i + 1}',
                  ),
                ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Game'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
