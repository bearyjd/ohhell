import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohhell_client/src/screens/scorer_setup_screen.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(home: child),
    );

void main() {
  group('ScorerSetupScreen — player count bounds', () {
    testWidgets('starts with 4 players and both stepper buttons enabled',
        (tester) async {
      await tester.pumpWidget(_wrap(const ScorerSetupScreen()));

      final decrement = tester
          .widget<IconButton>(find.byKey(const Key('decrement_players')));
      final increment = tester
          .widget<IconButton>(find.byKey(const Key('increment_players')));

      expect(decrement.onPressed, isNotNull);
      expect(increment.onPressed, isNotNull);
    });

    testWidgets('decrement button is disabled at minimum (3 players)',
        (tester) async {
      await tester.pumpWidget(_wrap(const ScorerSetupScreen()));

      // Tap decrement once to go from 4 → 3.
      await tester.tap(find.byKey(const Key('decrement_players')));
      await tester.pump();

      final decrement = tester
          .widget<IconButton>(find.byKey(const Key('decrement_players')));
      expect(decrement.onPressed, isNull,
          reason: 'decrement should be disabled at 3 players');

      // Increment is still enabled at 3.
      final increment = tester
          .widget<IconButton>(find.byKey(const Key('increment_players')));
      expect(increment.onPressed, isNotNull);
    });

    testWidgets('increment button is disabled at maximum (7 players)',
        (tester) async {
      await tester.pumpWidget(_wrap(const ScorerSetupScreen()));

      // Tap increment 3 times to go from 4 → 7.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('increment_players')));
        await tester.pump();
      }

      final increment = tester
          .widget<IconButton>(find.byKey(const Key('increment_players')));
      expect(increment.onPressed, isNull,
          reason: 'increment should be disabled at 7 players');

      // Decrement is still enabled at 7.
      final decrement = tester
          .widget<IconButton>(find.byKey(const Key('decrement_players')));
      expect(decrement.onPressed, isNotNull);
    });

    testWidgets('cannot go below 3 players with repeated taps',
        (tester) async {
      await tester.pumpWidget(_wrap(const ScorerSetupScreen()));

      // Tap decrement many times — should clamp at 3.
      for (var i = 0; i < 10; i++) {
        await tester.tap(
          find.byKey(const Key('decrement_players')),
          warnIfMissed: false,
        );
        await tester.pump();
      }

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('cannot go above 7 players with repeated taps',
        (tester) async {
      await tester.pumpWidget(_wrap(const ScorerSetupScreen()));

      // Tap increment many times — should clamp at 7.
      for (var i = 0; i < 10; i++) {
        await tester.tap(
          find.byKey(const Key('increment_players')),
          warnIfMissed: false,
        );
        await tester.pump();
      }

      expect(find.text('7'), findsOneWidget);
    });
  });
}
