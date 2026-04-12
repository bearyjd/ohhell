import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';

class CardWidget extends StatelessWidget {
  const CardWidget({
    required this.suit,
    required this.rank,
    this.isFaceDown = false,
    this.isSelected = false,
    this.isPlayable = true,
    this.onTap,
    super.key,
  });

  final String suit;
  final String rank;
  final bool isFaceDown;
  final bool isSelected;
  final bool isPlayable;
  final VoidCallback? onTap;

  static const double _cardWidth = 60;
  static const double _cardHeight = 84;
  static const double _borderRadius = 8;

  bool get _isRedSuit => suit == '♥' || suit == '♦';

  String get _semanticLabel {
    final suitName = switch (suit) {
      '♠' => 'Spades',
      '♥' => 'Hearts',
      '♦' => 'Diamonds',
      '♣' => 'Clubs',
      _ => suit,
    };
    final rankName = switch (rank) {
      'A' => 'Ace',
      'K' => 'King',
      'Q' => 'Queen',
      'J' => 'Jack',
      _ => rank,
    };
    return '$rankName of $suitName';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isFaceDown ? 'Face-down card' : _semanticLabel,
      button: onTap != null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(
          0,
          isSelected ? -12 : 0,
          0,
        ),
        child: GestureDetector(
          onTap: isPlayable ? onTap : null,
          child: Opacity(
            opacity: isPlayable ? 1.0 : 0.5,
            child: Container(
              width: _cardWidth,
              height: _cardHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_borderRadius),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child:
                  isFaceDown ? _buildFaceDown() : _buildFaceUp(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFaceDown() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_borderRadius),
      child: CustomPaint(
        painter: _CardBackPainter(),
        size: const Size(_cardWidth, _cardHeight),
      ),
    );
  }

  Widget _buildFaceUp() {
    final suitColor =
        _isRedSuit ? AppColors.suitRed : AppColors.suitBlack;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(_borderRadius),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Stack(
          children: [
            // Top-left rank + suit
            Positioned(
              top: 0,
              left: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rank,
                    style: TextStyle(
                      color: suitColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    suit,
                    style: TextStyle(
                      color: suitColor,
                      fontSize: 10,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            // Center suit
            Center(
              child: Text(
                suit,
                style: TextStyle(
                  color: suitColor,
                  fontSize: 28,
                ),
              ),
            ),
            // Bottom-right rank + suit (rotated)
            Positioned(
              bottom: 0,
              right: 2,
              child: Transform.rotate(
                angle: math.pi,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rank,
                      style: TextStyle(
                        color: suitColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      suit,
                      style: TextStyle(
                        color: suitColor,
                        fontSize: 10,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bgPaint = Paint()..color = AppColors.cardBack;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(8),
      ),
      bgPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = const Color(0xFF1976D2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Offset(3, 3) & Size(size.width - 6, size.height - 6),
        const Radius.circular(6),
      ),
      borderPaint,
    );

    // Diamond pattern
    final diamondPaint = Paint()
      ..color = const Color(0x331976D2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const spacing = 10.0;
    const halfSize = 5.0;

    for (double y = spacing; y < size.height; y += spacing) {
      for (double x = spacing; x < size.width; x += spacing) {
        final path = Path()
          ..moveTo(x, y - halfSize)
          ..lineTo(x + halfSize, y)
          ..lineTo(x, y + halfSize)
          ..lineTo(x - halfSize, y)
          ..close();
        canvas.drawPath(path, diamondPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
