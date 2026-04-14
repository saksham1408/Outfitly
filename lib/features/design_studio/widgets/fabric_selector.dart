import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';

class FabricSelector extends StatelessWidget {
  final List<String> fabrics;
  final String? selectedFabric;
  final ValueChanged<String> onSelected;

  const FabricSelector({
    super.key,
    required this.fabrics,
    required this.selectedFabric,
    required this.onSelected,
  });

  // Fabric-to-color mapping for visual swatches.
  static const _fabricColors = <String, Color>{
    'Cotton Oxford': Color(0xFFE8E0D0),
    'Linen Blend': Color(0xFFF5EDE0),
    'Supima Cotton': Color(0xFFF0F0F0),
    'Cotton Poplin': Color(0xFFEDE8E0),
    'Chambray': Color(0xFF8AACCF),
    'Silk Blend': Color(0xFFD4C8B8),
    'Pure Linen': Color(0xFFF2EBD9),
    'Cotton Linen': Color(0xFFE5DFD0),
    'Khadi Linen': Color(0xFFD9D0C0),
    'Stretch Cotton': Color(0xFFE0D8C8),
    'Cotton Twill': Color(0xFFD8CEBC),
    'Wool Blend': Color(0xFF4A4A4A),
    'Poly-Viscose': Color(0xFF3A3A3A),
    'Terry Rayon': Color(0xFF5A5A5A),
    'Merino Wool': Color(0xFF2C2C3A),
    'Poly-Wool': Color(0xFF3C3C4A),
    'Italian Linen': Color(0xFFF0E8D4),
    'Cotton Voile': Color(0xFFFAF5EC),
    'Georgette': Color(0xFFE8D8D0),
    'Modal Silk': Color(0xFFD0C8C0),
    'Raw Silk': Color(0xFFC8A880),
    'Art Silk': Color(0xFFD4B898),
    'Banarasi Silk': Color(0xFFB8860B),
    'Jacquard Silk': Color(0xFF8B0000),
    'Brocade': Color(0xFFC5A55A),
    'Velvet': Color(0xFF4B0050),
    'Khadi': Color(0xFFE2D8C8),
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fabric', style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text('Select your preferred fabric', style: AppTypography.bodySmall),
        const SizedBox(height: AppSpacing.base),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: fabrics.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final fabric = fabrics[index];
              final isSelected = selectedFabric == fabric;
              final color = _fabricColors[fabric] ?? AppColors.surfaceVariant;

              return GestureDetector(
                onTap: () => onSelected(fabric),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.border,
                          width: isSelected ? 2.5 : 0.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.accent.withAlpha(60),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SizedBox(
                      width: 64,
                      child: Text(
                        fabric,
                        style: AppTypography.labelSmall.copyWith(
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
