import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';
import '../models/product_model.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mainImage = product.images.isNotEmpty ? product.images.first : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product Image ──
            Expanded(
              child: mainImage != null
                  ? Image.network(
                      mainImage,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => _placeholder(),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return _placeholder(loading: true);
                      },
                    )
                  : _placeholder(),
            ),

            // ── Info ──
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTypography.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (product.fabricOptions.isNotEmpty)
                    Text(
                      product.fabricOptions.first,
                      style: AppTypography.labelSmall,
                      maxLines: 1,
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    product.formattedPrice,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceVariant,
      child: Center(
        child: loading
            ? const CircularProgressIndicator(strokeWidth: 2)
            : Icon(
                Icons.checkroom_rounded,
                size: 40,
                color: AppColors.textTertiary.withAlpha(100),
              ),
      ),
    );
  }
}
