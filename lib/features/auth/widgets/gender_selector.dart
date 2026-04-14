import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';

class GenderSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelected;

  const GenderSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  static const _options = [
    ('male', 'Male'),
    ('female', 'Female'),
    ('non-binary', 'Non-Binary'),
    ('prefer-not-to-say', 'Rather not say'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender', style: AppTypography.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _options.map((option) {
            final isSelected = selected == option.$1;
            return ChoiceChip(
              label: Text(option.$2),
              selected: isSelected,
              onSelected: (_) => onSelected(option.$1),
              selectedColor: AppColors.primary,
              labelStyle: AppTypography.labelMedium.copyWith(
                color: isSelected
                    ? AppColors.textOnPrimary
                    : AppColors.textPrimary,
              ),
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
