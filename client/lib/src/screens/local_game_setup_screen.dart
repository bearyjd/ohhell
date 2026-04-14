import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_engine/ohhell_engine.dart';

import 'package:ohhell_client/src/providers/local_game_provider.dart';
import 'package:ohhell_client/src/providers/settings_provider.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';

class LocalGameSetupScreen extends ConsumerStatefulWidget {
  const LocalGameSetupScreen({super.key});

  @override
  ConsumerState<LocalGameSetupScreen> createState() =>
      _LocalGameSetupScreenState();
}

class _LocalGameSetupScreenState extends ConsumerState<LocalGameSetupScreen> {
  final _nameController = TextEditingController();
  late BotDifficulty _difficulty;
  late int _botCount;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _difficulty = settings.botDifficulty;
    _botCount = settings.botCount;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startGame() {
    final settings = ref.read(settingsProvider);
    ref.read(localGameProvider.notifier).startGame(
          humanName: _nameController.text.trim(),
          botCount: _botCount,
          difficulty: _difficulty,
          strictScoring: settings.strictScoring,
        );
    context.go('/local-game');
  }

  @override
  Widget build(BuildContext context) {
    final nameEmpty = _nameController.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        title: const Text('Play vs Bots'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Your Name'),
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 24),
                Text(
                  'Bot Count ($_botCount)',
                  style: const TextStyle(color: AppColors.textOnDark),
                ),
                Slider(
                  value: _botCount.toDouble(),
                  min: 2,
                  max: 6,
                  divisions: 4,
                  activeColor: AppColors.amber,
                  onChanged: (v) => setState(() => _botCount = v.round()),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Difficulty',
                  style: TextStyle(color: AppColors.textOnDark),
                ),
                const SizedBox(height: 8),
                SegmentedButton<BotDifficulty>(
                  segments: const [
                    ButtonSegment(
                      value: BotDifficulty.easy,
                      label: Text('Easy'),
                    ),
                    ButtonSegment(
                      value: BotDifficulty.medium,
                      label: Text('Medium'),
                    ),
                    ButtonSegment(
                      value: BotDifficulty.hard,
                      label: Text('Hard'),
                    ),
                  ],
                  selected: {_difficulty},
                  onSelectionChanged: (set) =>
                      setState(() => _difficulty = set.first),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: nameEmpty ? null : _startGame,
                  child: const Text('Start Game'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
