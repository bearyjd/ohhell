import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohhell_client/src/widgets/card_widget.dart';
import 'package:ohhell_client/src/widgets/hand_widget.dart';

void main() {
  group('HandWidget', () {
    const testCards = <CardRecord>[
      (suit: '♠', rank: 'A', isPlayable: true),
      (suit: '♥', rank: 'K', isPlayable: true),
      (suit: '♦', rank: 'Q', isPlayable: true),
    ];

    testWidgets('renders correct number of CardWidgets', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HandWidget(cards: testCards),
            ),
          ),
        ),
      );

      expect(find.byType(CardWidget), findsNWidgets(testCards.length));
    });

    testWidgets('tapping a card calls onCardTap with correct index',
        (tester) async {
      final tappedIndices = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HandWidget(
                cards: testCards,
                onCardTap: tappedIndices.add,
              ),
            ),
          ),
        ),
      );

      // Tap the first card
      final cards = tester.widgetList<CardWidget>(find.byType(CardWidget));
      final firstCard = cards.first;
      await tester.tap(find.byWidget(firstCard));
      await tester.pump();

      expect(tappedIndices, contains(0));
    });

    testWidgets('selected card index is forwarded correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HandWidget(
                cards: testCards,
                selectedIndex: 1,
              ),
            ),
          ),
        ),
      );

      final cardWidgets = tester
          .widgetList<CardWidget>(find.byType(CardWidget))
          .toList();

      expect(cardWidgets[0].isSelected, isFalse);
      expect(cardWidgets[1].isSelected, isTrue);
      expect(cardWidgets[2].isSelected, isFalse);
    });

    testWidgets('renders nothing when cards list is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HandWidget(cards: []),
            ),
          ),
        ),
      );

      expect(find.byType(CardWidget), findsNothing);
    });

    testWidgets('renders face-down cards when faceDown is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HandWidget(cards: testCards, faceDown: true),
            ),
          ),
        ),
      );

      final cardWidgets = tester
          .widgetList<CardWidget>(find.byType(CardWidget))
          .toList();

      for (final card in cardWidgets) {
        expect(card.isFaceDown, isTrue);
      }
    });
  });
}
