import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/theme.dart';

/// Shared section header used across every home-feed module.
///
/// Pulled into its own widget so the visual rhythm — italic
/// Newsreader display + a 2dp accent rule + optional caption +
/// optional "See all" pill — stays identical from "The Edit"
/// through the atelier story and beyond. Editorial fashion
/// apps (Tatacliq Luxe, Nykaa Fashion) lean on consistent
/// section heads to make the home read like a magazine instead
/// of a product grid; this is that contract in one widget.
class EditorialSectionHeader extends StatelessWidget {
  const EditorialSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.caption,
    this.actionLabel,
    this.onActionTap,
  });

  /// Big italic display title — e.g. "The Edit", "From Our Atelier".
  final String title;

  /// Tiny tracked-out label above the title — e.g. "CURATED".
  /// Optional; omit for a calmer header.
  final String? eyebrow;

  /// One-line subtitle below the title — e.g. "Hand-picked for the
  /// festive feast." Optional.
  final String? caption;

  /// Right-side action label — typically "See all". When this is
  /// set, [onActionTap] should be too (the widget no-ops the tap
  /// otherwise).
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  title,
                  style: GoogleFonts.newsreader(
                    fontSize: 26,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                    height: 1.05,
                    letterSpacing: -0.3,
                  ),
                ),
                Container(
                  height: 2,
                  width: 56,
                  margin: const EdgeInsets.only(top: 6),
                  color: AppColors.accent,
                ),
                if (caption != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    caption!,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 6),
              child: _ActionPill(
                label: actionLabel!,
                onTap: onActionTap,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
