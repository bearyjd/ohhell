import 'package:flutter/material.dart';
import 'package:ohhell_client/src/widgets/card_widget.dart';

typedef CardRecord = ({String suit, String rank, bool isPlayable});

class HandWidget extends StatelessWidget {
  const HandWidget({
    required this.cards,
    this.selectedIndex,
    this.onCardTap,
    this.faceDown = false,
    super.key,
  });

  final List<CardRecord> cards;
  final int? selectedIndex;
  final void Function(int index)? onCardTap;
  final bool faceDown;

  static const double _cardOffset = 44.0;
  static const double _cardWidth = 60.0;
  static const double _cardHeight = 84.0;
  static const double _selectedLift = 12.0;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalWidth =
        _cardOffset * (cards.length - 1) + _cardWidth;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: totalWidth,
        height: _cardHeight + _selectedLift,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (int i = 0; i < cards.length; i++)
              Positioned(
                left: i * _cardOffset,
                bottom: 0,
                child: CardWidget(
                  suit: cards[i].suit,
                  rank: cards[i].rank,
                  isFaceDown: faceDown,
                  isSelected: selectedIndex == i,
                  isPlayable: cards[i].isPlayable,
                  onTap:
                      onCardTap != null ? () => onCardTap!(i) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
