import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../models/combo_draft.dart';
import '../models/family_member.dart';

/// First screen of the Family & Combos flow.
///
/// Users land here from the Home-screen "Family & Combos" entry
/// and choose one of two paths:
///
///   * **Couple Combinations** — predefined roster (Father +
///     Mother) so the user goes straight to the matching sets
///     without an interstitial builder. Ideal for the
///     anniversary / engagement use-case.
///   * **Family Sets** — opens the roster builder so the user
///     can compose their exact household (grandparents, kids
///     by gender + count).
///
/// Visually the screen is two large cards stacked vertically,
/// each filling roughly half the viewport. Generous typography +
/// a contrasting gradient on each card sells the "premium
/// collection" framing the spec asks for.
class ComboSelectionScreen extends StatelessWidget {
  const ComboSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Family & Combos',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              // Lede — frames the two choices below as a
              // single decision the user is being walked through.
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Coordinated for the moment',
                  style: GoogleFonts.newsreader(
                    fontSize: 30,
                    fontStyle: FontStyle.italic,
                    color: AppColors.primary,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 2,
                  width: 56,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pick a path. We\'ll match every piece — palette, fabric, embroidery — across the entire group.',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Two cards filling the rest of the viewport. Equal
              // flex on each so they read as parallel choices,
              // not "primary + secondary".
              Expanded(
                child: _ChoiceCard(
                  // Top card — Couple. Deep purple gradient with
                  // an accent-coloured ribbon framing the
                  // headline. Tap routes straight to the
                  // results screen with the predefined roster.
                  title: 'Couple Combinations',
                  subtitle: 'Two looks, one palette — for the anniversary, the engagement, the date night.',
                  icon: Icons.favorite_rounded,
                  gradientStart: AppColors.primary,
                  gradientEnd: const Color(0xFF1A2A6C),
                  accentLabel: 'TWO PIECES',
                  onTap: () {
                    // Couple shortcut: skip the family-builder
                    // and walk straight into the customization
                    // wizard with a pre-baked Father+Mother
                    // roster.
                    context.push(
                      '/combos/garments',
                      extra: const ComboDraft(
                        roster: CoupleRoster.defaultRoster,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _ChoiceCard(
                  // Bottom card — Family. Warm gold-to-amber
                  // gradient — feels festive and matches the
                  // "Diwali / wedding / Eid" reference style.
                  title: 'Family Sets',
                  subtitle: 'Build your roster — grandparents, parents, kids — and we\'ll dress every generation in step.',
                  icon: Icons.family_restroom_rounded,
                  gradientStart: const Color(0xFF8B500A),
                  gradientEnd: const Color(0xFFB8860B),
                  accentLabel: 'BUILD YOUR ROSTER',
                  onTap: () {
                    context.push('/combos/builder');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the two top-level cards. Filling the parent's height
/// (the parent uses Expanded) so both cards feel premium and
/// "the only thing on this screen" — exactly the immersive,
/// massive-card framing the spec asks for.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
    required this.accentLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color gradientStart;
  final Color gradientEnd;
  final String accentLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [gradientStart, gradientEnd],
            ),
            boxShadow: [
              BoxShadow(
                color: gradientStart.withAlpha(60),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Stack(
            children: [
              // Background icon — large + ghosted so it's a
              // textural element, not a literal icon-with-label.
              Positioned(
                right: -24,
                bottom: -24,
                child: Icon(
                  icon,
                  size: 180,
                  color: Colors.white.withAlpha(28),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(48),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      accentLabel,
                      style: GoogleFonts.manrope(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: GoogleFonts.newsreader(
                      fontSize: 30,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: Colors.white.withAlpha(220),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Begin',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
