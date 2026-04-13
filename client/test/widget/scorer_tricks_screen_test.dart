import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohhell_client/src/providers/scorekeeper_provider.dart';
import 'package:ohhell_client/src/screens/scorer_tricks_screen.dart';

/// Builds a notifier with a game already started so the screen can render.
ScorekeeperNotifier _startedNotifier(List<String> names) {
  final n = ScorekeeperNotifier();
  n.startGame(names);
  return n;
}

Widget _wrap(Widget child, ScorekeeperNotifier notifier) => ProviderScope(
      overrides: [
        scorekeeperProvider.overrideWith((_) => notifier),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  // 3-player game: round 0 has cardsPerHand = 1 (schedule starts at 1).
  const names = ['Alice', 'Bob', 'Charlie'];

  group('ScorerTricksScreen — End Round button', () {
    testWidgets('is disabled when tricks sum does not equal cardsPerHand',
        (tester) async {
      final notifier = _startedNotifier(names);
      // Set bids so the screen renders cards correctly (optional but realistic).
      for (final name in names) {
        notifier.setBid(name, 0);
      }
      // Leave tricks at defaults (all 0) — sum 0 ≠ 1 (cardsPerHand for round 0).

      await tester.pumpWidget(
        _wrap(ScorerTricksScreen(round: 0), notifier),
      );

      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('end_round_button')),
      );
      expect(button.onPressed, isNull,
          reason:
              'End Round should be disabled when trick total ≠ cardsPerHand');
    });

    testWidgets('is enabled when tricks sum equals cardsPerHand',
        (tester) async {
      final notifier = _startedNotifier(names);
      for (final name in names) {
        notifier.setBid(name, 0);
      }
      // Set exactly 1 trick for Alice (sum = 1 = cardsPerHand for round 0).
      notifier.setTricks('Alice', 1);

      await tester.pumpWidget(
        _wrap(ScorerTricksScreen(round: 0), notifier),
      );

      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('end_round_button')),
      );
      expect(button.onPressed, isNotNull,
          reason: 'End Round should be enabled when trick total = cardsPerHand');
    });

    testWidgets('becomes enabled after adjusting tricks to match cardsPerHand',
        (tester) async {
      final notifier = _startedNotifier(names);
      for (final name in names) {
        notifier.setBid(name, 0);
      }

      await tester.pumpWidget(
        _wrap(ScorerTricksScreen(round: 0), notifier),
      );

      // Initially disabled.
      var button = tester.widget<ElevatedButton>(
        find.byKey(const Key('end_round_button')),
      );
      expect(button.onPressed, isNull);

      // Tap the '+' button for Alice to set her tricks to 1.
      // The add buttons are IconButtons next to each player card.
      // Alice is the first player, so find the first add_circle_outline icon.
      final addButtons = find.byIcon(Icons.add_circle_outline);
      await tester.tap(addButtons.first);
      await tester.pump();

      // Now sum = 1 = cardsPerHand → button enabled.
      button = tester.widget<ElevatedButton>(
        find.byKey(const Key('end_round_button')),
      );
      expect(button.onPressed, isNotNull);
    });
  });
}
