import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/models/sub_category.dart';

/// Data-driven subcategory row for MEN / WOMEN / KIDS.
class SubCategoryRow extends StatelessWidget {
  final List<SubCategory> subCategories;
  final String? selectedId;
  final ValueChanged<SubCategory> onTap;

  const SubCategoryRow({
    super.key,
    required this.subCategories,
    required this.onTap,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: subCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final cat = subCategories[index];
          final isSelected = cat.id == selectedId;
          return _SubCategoryBubble(
            category: cat,
            isSelected: isSelected,
            onTap: () => onTap(cat),
          );
        },
      ),
    );
  }
}

class _SubCategoryBubble extends StatelessWidget {
  final SubCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubCategoryBubble({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
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
                color: isSelected ? AppColors.primary : AppColors.accent.withAlpha(40),
                width: isSelected ? 2.5 : 2,
              ),
              image: category.imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(category.imageUrl!),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withAlpha(30),
                        BlendMode.darken,
                      ),
                    )
                  : null,
            ),
            child: category.imageUrl == null
                ? const Center(
                    child: Icon(
                      Icons.checkroom_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 76,
            child: Text(
              category.name,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
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
