import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';
import '../models/customization_options.dart';

class OptionTile extends StatelessWidget {
  final CustomizationOption option;
  final bool selected;
  final VoidCallback onTap;

  const OptionTile({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder icon for the option visual
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.textOnPrimary.withAlpha(30)
                    : AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.style_rounded,
                size: 22,
                color: selected
                    ? AppColors.textOnPrimary
                    : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              option.label,
              style: AppTypography.titleSmall.copyWith(
                color: selected
                    ? AppColors.textOnPrimary
                    : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (option.description != null) ...[
              const SizedBox(height: 2),
              Text(
                option.description!,
                style: AppTypography.labelSmall.copyWith(
                  color: selected
                      ? AppColors.textOnPrimary.withAlpha(180)
                      : AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
