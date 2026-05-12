import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/theme.dart';
import 'editorial_section_header.dart';

/// "Browse by Occasion" — a horizontal scroll of circular
/// occasion badges that breaks the home feed's gradient-card
/// rhythm.
///
/// Ethnic wear is bought occasion-first more than category-first
/// — a customer planning a wedding doesn't go searching for
/// "kurta", they go searching for "sangeet outfit" or "wedding
/// reception". This strip exposes that mental model directly:
/// pick the moment you're dressing for, land on a filtered
/// catalog.
///
/// Visually distinct from the rest of the home — circular
/// badges + label below (vs. rectangular gradient cards
/// everywhere else) — so the eye gets a tactile change of
/// pace as you scroll.
///
/// Eight occasions ship hardcoded. Long-term these become rows
/// in a Postgres `occasions` table the merchandising team
/// curates; the badge palette + icon are baked into this file
/// for now so the strip ships without a migration.
class OccasionPickerStrip extends StatelessWidget {
  const OccasionPickerStrip({super.key});

  static const _occasions = <_Occasion>[
    _Occasion(
      label: 'Wedding',
      icon: Icons.diamond_outlined,
      gradient: [Color(0xFF7A2E1F), Color(0xFFD4AF37)],
    ),
    _Occasion(
      label: 'Sangeet',
      icon: Icons.music_note_rounded,
      gradient: [Color(0xFF3B1A4F), Color(0xFFB8860B)],
    ),
    _Occasion(
      label: 'Mehndi',
      icon: Icons.local_florist_outlined,
      gradient: [Color(0xFF2F4A2A), Color(0xFFCAD96A)],
    ),
    _Occasion(
      label: 'Reception',
      icon: Icons.nightlife_rounded,
      gradient: [Color(0xFF0B1B3B), Color(0xFFC9A86A)],
    ),
    _Occasion(
      label: 'Festive',
      icon: Icons.celebration_rounded,
      gradient: [Color(0xFFB8860B), Color(0xFFFCEAD7)],
    ),
    _Occasion(
      label: 'Cocktail',
      icon: Icons.wine_bar_rounded,
      gradient: [Color(0xFF6B3B00), Color(0xFFE6C99A)],
    ),
    _Occasion(
      label: 'Office',
      icon: Icons.work_outline_rounded,
      gradient: [Color(0xFF1F3A57), Color(0xFFA9B9CC)],
    ),
    _Occasion(
      label: 'Casual',
      icon: Icons.weekend_outlined,
      gradient: [Color(0xFFE7EFE0), Color(0xFFB8CFA3)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EditorialSectionHeader(
          eyebrow: 'Shop the moment',
          title: 'Browse by Occasion',
          caption:
              'Pick the event — we surface the silhouettes, fabrics, and edits made for it.',
        ),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _occasions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              return _OccasionTile(occasion: _occasions[i]);
            },
          ),
        ),
      ],
    );
  }
}

class _Occasion {
  const _Occasion({
    required this.label,
    required this.icon,
    required this.gradient,
  });

  final String label;
  final IconData icon;
  final List<Color> gradient;
}

class _OccasionTile extends StatelessWidget {
  const _OccasionTile({required this.occasion});

  final _Occasion occasion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/catalog'),
          borderRadius: BorderRadius.circular(60),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: occasion.gradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: occasion.gradient.first.withAlpha(110),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Subtle inner highlight — gives the circle
                    // a polished "metal disc" feel instead of
                    // looking like a flat blob.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: const Alignment(-0.4, -0.4),
                              radius: 0.9,
                              colors: [
                                Colors.white.withAlpha(60),
                                Colors.white.withAlpha(0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(
                        occasion.icon,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                occasion.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
