import 'package:flutter/material.dart';

import 'shimmer_box.dart';

/// Loading shimmer for a horizontal category row.
class CategoryRowShimmer extends StatelessWidget {
  const CategoryRowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ShimmerBox(
              width: 64,
              height: 64,
              shape: BoxShape.circle,
            ),
            const SizedBox(height: 8),
            ShimmerBox(
              width: 56,
              height: 10,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}
