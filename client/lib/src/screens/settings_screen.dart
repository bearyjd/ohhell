import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_engine/ohhell_engine.dart';

import 'package:ohhell_client/src/providers/settings_provider.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Game Defaults',
            children: [
              _LabelRow(
                label: 'Bot Difficulty',
                child: SegmentedButton<BotDifficulty>(
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
                  selected: {settings.botDifficulty},
                  onSelectionChanged: (set) =>
                      notifier.updateBotDifficulty(set.first),
                ),
              ),
              _LabelRow(
                label: 'Default Bots  (${settings.botCount})',
                child: Slider(
                  value: settings.botCount.toDouble(),
                  min: 1,
                  max: 6,
                  divisions: 5,
                  activeColor: AppColors.amber,
                  onChanged: (v) => notifier.updateBotCount(v.round()),
                ),
              ),
              SwitchListTile(
                title: const Text('Strict Scoring'),
                subtitle: const Text(
                  'Wrong bid = negative tricks (harder penalty)',
                ),
                value: settings.strictScoring,
                activeThumbColor: AppColors.amber,
                onChanged: (v) => notifier.updateStrictScoring(strict: v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SectionCard(
            title: 'About',
            children: [
              ListTile(
                title: Text('Version'),
                trailing: Text('0.1.x'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textOnDark.withAlpha(180),
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
