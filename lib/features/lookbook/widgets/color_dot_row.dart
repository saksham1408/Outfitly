import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';

class ColorDotRow extends StatelessWidget {
  final List<String> colors;
  final double dotSize;

  const ColorDotRow({
    super.key,
    required this.colors,
    this.dotSize = 14,
  });

  static const _colorMap = <String, Color>{
    'Gold': Color(0xFFD4A853),
    'Maroon': Color(0xFF800000),
    'Navy': Color(0xFF1B2A4A),
    'Emerald': Color(0xFF2E7D4F),
    'White': Color(0xFFFAFAFA),
    'Sky Blue': Color(0xFF87CEEB),
    'Beige': Color(0xFFF5F0E1),
    'Olive': Color(0xFF6B7C3F),
    'Light Blue': Color(0xFFADD8E6),
    'Pink': Color(0xFFF4C2C2),
    'Lavender': Color(0xFFB8A9D0),
    'Charcoal': Color(0xFF36454F),
    'Brown': Color(0xFF6B4423),
    'Forest Green': Color(0xFF228B22),
    'Ivory': Color(0xFFFFFFF0),
    'Peach': Color(0xFFFFDAB9),
    'Mint': Color(0xFF98FB98),
    'Powder Blue': Color(0xFFB0E0E6),
    'Indigo': Color(0xFF3F51B5),
    'Light Wash': Color(0xFF8AACCF),
    'Dark Wash': Color(0xFF3A5A8C),
    'Natural': Color(0xFFE8DCC8),
    'Off White': Color(0xFFFAF0E6),
    'Earthy Brown': Color(0xFF8B6914),
    'Slate': Color(0xFF708090),
    'Royal Blue': Color(0xFF2C3E8C),
    'Burgundy': Color(0xFF800020),
    'Black': Color(0xFF1A1A1A),
    'Deep Purple': Color(0xFF4A0080),
  };

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        ...colors.take(6).map((colorName) {
          final color = _colorMap[colorName] ?? AppColors.textTertiary;
          return Container(
            width: dotSize,
            height: dotSize,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: color == const Color(0xFFFAFAFA) ||
                        color == const Color(0xFFFFFFF0) ||
                        color == const Color(0xFFFAF0E6)
                    ? AppColors.border
                    : Colors.transparent,
                width: 0.5,
              ),
            ),
          );
        }),
        if (colors.length > 6)
          Text(
            '+${colors.length - 6}',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
      ],
    );
  }
}
