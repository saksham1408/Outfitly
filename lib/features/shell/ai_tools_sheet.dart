import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme.dart';

/// Modal bottom sheet that surfaces the three AI experiences in one
/// place — opened from the centre "AI" button on the bottom nav.
///
/// Each row dismisses the sheet and pushes the matching route, so
/// individual AI tools still have their own full-screen surfaces;
/// the sheet is just a launcher.
///
/// Pop result is the chosen tool name (debug-only) or null if the
/// user dismissed without picking. Callers usually don't await the
/// result — the navigation happens inside the row's onTap.
Future<String?> showAiToolsSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AiToolsSheet(),
  );
}

class _AiToolsSheet extends StatelessWidget {
  const _AiToolsSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle.
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'AI Tools',
            style: GoogleFonts.newsreader(
              fontSize: 24,
              fontStyle: FontStyle.italic,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick which kind of help you want.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),

          // ── 1. VASTRAHUB AI ──
          _AiToolRow(
            icon: Icons.auto_awesome,
            iconBg: AppColors.primary,
            title: 'VASTRAHUB AI',
            subtitle:
                'Chat with the personal stylist about anything fashion.',
            onTap: () {
              Navigator.of(context).pop('outfitly-ai');
              context.push('/outfitly-ai');
            },
          ),
          const SizedBox(height: 10),

          // ── 2. Dress Me ──
          _AiToolRow(
            icon: Icons.auto_fix_high,
            iconBg: AppColors.accent,
            title: 'Dress Me',
            subtitle:
                'Build a daily outfit from clothes already in your closet.',
            onTap: () {
              Navigator.of(context).pop('dress-me');
              context.push('/digital-wardrobe/stylist');
            },
          ),
          const SizedBox(height: 10),

          // ── 3. Recreate a Look ──
          _AiToolRow(
            icon: Icons.photo_camera_outlined,
            iconBg: AppColors.primaryLight,
            title: 'Recreate a Look',
            subtitle:
                'Upload an inspo photo and we\'ll design it for tailoring.',
            onTap: () {
              Navigator.of(context).pop('recreate-look');
              context.push('/recreate-look');
            },
          ),
        ],
      ),
    );
  }
}

/// One option row inside [_AiToolsSheet]. Pulled out so each row's
/// padding / icon-tile / arrow chevron stays consistent and the
/// sheet body reads as a list of three near-identical entries.
class _AiToolRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AiToolRow({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
