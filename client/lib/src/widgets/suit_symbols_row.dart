import 'package:flutter/material.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';

class SuitSymbolsRow extends StatelessWidget {
  const SuitSymbolsRow({required this.fontSize, super.key});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '♠',
          style: TextStyle(
            fontSize: fontSize,
            color: AppColors.textOnDark.withAlpha(200),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '♥',
          style: TextStyle(
            fontSize: fontSize,
            color: AppColors.suitRed,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '♦',
          style: TextStyle(
            fontSize: fontSize,
            color: AppColors.suitRed,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '♣',
          style: TextStyle(
            fontSize: fontSize,
            color: AppColors.textOnDark.withAlpha(200),
          ),
        ),
      ],
    );
  }
}
