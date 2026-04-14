import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/screens/local_game_setup_screen.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp.router(
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, __) => child),
          GoRoute(path: '/local-game', builder: (_, __) => const SizedBox()),
        ]),
      ),
    );

void main() {
  group('LocalGameSetupScreen', () {
    testWidgets('shows player name, bot count, difficulty fields',
        (tester) async {
      await tester.pumpWidget(_wrap(const LocalGameSetupScreen()));
      expect(find.text('Your Name'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
    });

    testWidgets('Start Game button disabled when name is empty', (tester) async {
      await tester.pumpWidget(_wrap(const LocalGameSetupScreen()));
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNull);
    });

    testWidgets('Start Game button enabled when name is entered', (tester) async {
      await tester.pumpWidget(_wrap(const LocalGameSetupScreen()));
      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pump();
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNotNull);
    });
  });
}
