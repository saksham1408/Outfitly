import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../data/tab_category.dart';

/// Reusable horizontal category row used by MEN and WOMEN tabs.
class TabCategoryRow extends StatelessWidget {
  final List<TabCategory> categories;
  final ValueChanged<TabCategory>? onCategoryTap;

  const TabCategoryRow({
    super.key,
    required this.categories,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return _CategoryBubble(
            category: cat,
            onTap: () => onCategoryTap?.call(cat),
          );
        },
      ),
    );
  }
}

class _CategoryBubble extends StatelessWidget {
  final TabCategory category;
  final VoidCallback onTap;

  const _CategoryBubble({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentContainer,
                  AppColors.accentLight,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accent.withAlpha(40),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                category.icon,
                color: AppColors.primary,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 76,
            child: Text(
              category.name,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
