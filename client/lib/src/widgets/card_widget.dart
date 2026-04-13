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

  static const double _cardWidth = 72;
  static const double _cardHeight = 100;
  static const double _borderRadius = 12;

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
          isSelected ? -14 : 0,
          0,
        ),
        child: GestureDetector(
          onTap: isPlayable ? onTap : null,
          child: Opacity(
            opacity: isPlayable ? 1.0 : 0.45,
            child: Container(
              width: _cardWidth,
              height: _cardHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_borderRadius),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 6,
                    offset: Offset(2, 3),
                  ),
                ],
              ),
              child: isFaceDown ? _buildFaceDown() : _buildFaceUp(),
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
    final stripColor =
        _isRedSuit ? AppColors.suitRed : const Color(0xFF1E293B);

    return ClipRRect(
      borderRadius: BorderRadius.circular(_borderRadius),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardSurface,
        ),
        child: Stack(
          children: [
            // Left accent strip
            Positioned(
              top: 0,
              left: 0,
              bottom: 0,
              child: Container(
                width: 6,
                color: stripColor,
              ),
            ),
            // Top-left rank + suit
            Positioned(
              top: 4,
              left: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rank,
                    style: TextStyle(
                      color: suitColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    suit,
                    style: TextStyle(
                      color: suitColor,
                      fontSize: 11,
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
                  fontSize: 32,
                ),
              ),
            ),
            // Bottom-right rank + suit (rotated 180°)
            Positioned(
              bottom: 4,
              right: 4,
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
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      suit,
                      style: TextStyle(
                        color: suitColor,
                        fontSize: 11,
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
    // Background: indigo-700
    final bgPaint = Paint()..color = const Color(0xFF312E81);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(12),
      ),
      bgPaint,
    );

    // Inner border: indigo-600, 2px stroke, 3px inset, radius 9
    final borderPaint = Paint()
      ..color = const Color(0xFF4338CA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Offset(3, 3) & Size(size.width - 6, size.height - 6),
        const Radius.circular(9),
      ),
      borderPaint,
    );

    // Concentric diamond pattern: semi-transparent indigo
    final diamondPaint = Paint()
      ..color = const Color(0x554338CA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const spacing = 12.0;
    const halfSize = 6.0;

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

    // 2×2 grid of suit symbols in center
    const suits = ['♠', '♥', '♦', '♣'];
    const textStyle = TextStyle(
      color: Color(0x884338CA),
      fontSize: 10.0,
    );

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    const gridSpacing = 14.0;
    final offsets = [
      Offset(centerX - gridSpacing / 2, centerY - gridSpacing / 2),
      Offset(centerX + gridSpacing / 2, centerY - gridSpacing / 2),
      Offset(centerX - gridSpacing / 2, centerY + gridSpacing / 2),
      Offset(centerX + gridSpacing / 2, centerY + gridSpacing / 2),
    ];

    for (var i = 0; i < suits.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: suits[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        offsets[i] - Offset(tp.width / 2, tp.height / 2),
      );
    }

  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
