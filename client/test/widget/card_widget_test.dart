import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohhell_client/src/widgets/card_widget.dart';

void main() {
  group('CardWidget', () {
    testWidgets('face-up card renders rank and suit text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CardWidget(suit: '♠', rank: 'A'),
            ),
          ),
        ),
      );

      // Rank appears twice (top-left and bottom-right rotated)
      expect(find.text('A'), findsWidgets);
      // Suit appears multiple times (top-left indicator + center)
      expect(find.text('♠'), findsWidgets);
    });

    testWidgets('face-down card does not show rank text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CardWidget(suit: '♥', rank: 'K', isFaceDown: true),
            ),
          ),
        ),
      );

      expect(find.text('K'), findsNothing);
      expect(find.text('♥'), findsNothing);
    });

    testWidgets('selected card has isSelected true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CardWidget(suit: '♦', rank: 'Q', isSelected: true),
            ),
          ),
        ),
      );

      final widget = tester.widget<CardWidget>(find.byType(CardWidget));
      expect(widget.isSelected, isTrue);
    });

    testWidgets('onTap is called when card is tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CardWidget(
                suit: '♣',
                rank: '7',
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CardWidget));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('onTap is not called when isPlayable is false',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CardWidget(
                suit: '♣',
                rank: '7',
                isPlayable: false,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CardWidget));
      await tester.pump();

      expect(tapped, isFalse);
    });

    testWidgets('card has semantic label for accessibility', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CardWidget(suit: '♠', rank: 'A'),
            ),
          ),
        ),
      );

      // Verify the Semantics widget is present with the correct label
      final semanticsWidget = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(CardWidget),
          matching: find.byType(Semantics),
        ).first,
      );
      expect(semanticsWidget.properties.label, equals('Ace of Spades'));
    });
  });
}
