import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/theme.dart';

/// Tiny editorial moment — a single italic quote that breaks
/// the home feed's product/CTA rhythm and signals brand voice.
///
/// Borrowed from the magazine-spread cadence: every premium
/// fashion publication intersperses a pull quote between
/// content blocks. We do the same here so the home feed feels
/// authored, not algorithmically dumped.
///
/// Pure decoration — no tap target, no analytics, no copy that
/// promises a route the user might expect to follow. It's a
/// breathing beat between two heavier sections.
class StyleQuoteCard extends StatelessWidget {
  const StyleQuoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withAlpha(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.format_quote_rounded,
                    size: 18,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'OUTFITLY · STYLE NOTE',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '“Tradition, tailored to today.\nNot worn — inhabited.”',
              style: GoogleFonts.newsreader(
                fontSize: 22,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
                height: 1.25,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  height: 1,
                  width: 24,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  'THE OUTFITLY ATELIER',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
