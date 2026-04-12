import 'package:flutter/material.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';
import 'package:ohhell_client/src/widgets/card_widget.dart';

typedef TrickPlay = ({String suit, String rank, String playerName});

class TrickPileWidget extends StatelessWidget {
  const TrickPileWidget({
    required this.plays,
    this.trumpSuit,
    super.key,
  });

  final List<TrickPlay> plays;
  final String? trumpSuit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: plays.isEmpty
              ? const Center(
                  child: Text(
                    'No cards played',
                    style: TextStyle(color: AppColors.textOnDark),
                  ),
                )
              : _buildPlays(),
        ),
        if (trumpSuit != null)
          Positioned(
            top: -8,
            right: -8,
            child: _TrumpBadge(suit: trumpSuit!),
          ),
      ],
    );
  }

  Widget _buildPlays() {
    // Layout positions for up to 4 players in cross/compass pattern
    final positions = _computePositions(plays.length);

    return Stack(
      children: [
        for (int i = 0; i < plays.length; i++)
          Positioned(
            left: positions[i].dx,
            top: positions[i].dy,
            child: _PlayedCard(play: plays[i]),
          ),
      ],
    );
  }

  List<Offset> _computePositions(int count) {
    // Center of 200x200 area, card is 60x84
    const cx = 70.0; // (200 - 60) / 2
    const cy = 58.0; // (200 - 84) / 2

    return switch (count) {
      1 => [const Offset(cx, cy)],
      2 => [
          const Offset(cx, 10),
          const Offset(cx, 106),
        ],
      3 => [
          const Offset(cx, 10),
          const Offset(10, 80),
          const Offset(130, 80),
        ],
      4 => [
          const Offset(cx, 4),
          const Offset(130, 58),
          const Offset(cx, 112),
          const Offset(10, 58),
        ],
      _ => [
          for (int i = 0; i < count; i++)
            Offset(
              70 + 30 * (i % 2 == 0 ? -1.0 : 1.0),
              70 + 30 * (i < 2 ? -1.0 : 1.0),
            ),
        ],
    };
  }
}

class _PlayedCard extends StatelessWidget {
  const _PlayedCard({required this.play});

  final TrickPlay play;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CardWidget(
          suit: play.suit,
          rank: play.rank,
        ),
        const SizedBox(height: 4),
        Text(
          play.playerName,
          style: const TextStyle(
            color: AppColors.textOnDark,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _TrumpBadge extends StatelessWidget {
  const _TrumpBadge({required this.suit});

  final String suit;

  @override
  Widget build(BuildContext context) {
    final isRed = suit == '♥' || suit == '♦';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 4,
            offset: Offset(1, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Trump',
            style: const TextStyle(
              color: AppColors.suitBlack,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            suit,
            style: TextStyle(
              color: isRed ? AppColors.suitRed : AppColors.suitBlack,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
