import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../models/combo_draft.dart';
import '../models/family_member.dart';

/// Interactive roster builder.
///
/// The screen shows six tiles — Grandfather, Grandmother,
/// Father, Mother, Son, Daughter — that toggle on tap. Adult
/// tiles are binary (1 if selected, 0 otherwise). Kid tiles
/// support a quantity counter so families with multiple kids
/// of the same gender don't have to add the same role twice.
///
/// State is held locally in `_quantities` (one int per role) so
/// the builder is a pure UI screen — the resulting roster is
/// only materialised when the user taps "Generate Matching
/// Sets" and gets routed to the results.
class FamilyBuilderScreen extends StatefulWidget {
  const FamilyBuilderScreen({super.key});

  @override
  State<FamilyBuilderScreen> createState() => _FamilyBuilderScreenState();
}

class _FamilyBuilderScreenState extends State<FamilyBuilderScreen> {
  /// One int per role. Adults are 0 or 1; kids can be 0 → many.
  /// We don't pre-populate (zero-by-default) so the user has to
  /// actively pick — feels like a deliberate choice rather than
  /// a "uncheck what doesn't apply" chore.
  final Map<FamilyRole, int> _quantities = {
    for (final r in FamilyRole.values) r: 0,
  };

  /// Compose the FamilyMember list from the current selections.
  /// Excludes anyone with quantity 0 so the matching repository
  /// doesn't have to filter again.
  List<FamilyMember> get _roster => [
        for (final entry in _quantities.entries)
          if (entry.value > 0)
            FamilyMember(role: entry.key, quantity: entry.value),
      ];

  /// Total head-count across the roster — drives the bottom
  /// CTA's badge ("3 people, 4 looks") so the user always sees
  /// the magnitude of what they're building.
  int get _totalCount =>
      _quantities.values.fold(0, (sum, n) => sum + n);

  void _toggleAdult(FamilyRole role) {
    setState(() {
      _quantities[role] = _quantities[role] == 1 ? 0 : 1;
    });
  }

  void _bumpKid(FamilyRole role, int delta) {
    setState(() {
      final current = _quantities[role] ?? 0;
      final next = (current + delta).clamp(0, 9);
      _quantities[role] = next;
    });
  }

  void _generate() {
    final roster = _roster;
    if (roster.isEmpty) return;
    // Family flow now walks through the customization wizard
    // (garments → fabric → sizes) before landing on the
    // matching-sets Lookbook. Same shape as the Couple shortcut
    // in ComboSelectionScreen — both paths share /combos/garments
    // as the next stop.
    context.push(
      '/combos/garments',
      extra: ComboDraft(roster: roster),
    );
  }

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
          'Family Sets',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              // Bottom padding clears the floating CTA so the last
              // kid tile isn't hidden under the button.
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
              children: [
                Text(
                  'Who are we styling today?',
                  style: GoogleFonts.newsreader(
                    fontSize: 28,
                    fontStyle: FontStyle.italic,
                    color: AppColors.primary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 2,
                  width: 56,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 10),
                Text(
                  'Tap to add — kids get a counter so multi-child families coordinate cleanly.',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),

                // ── Grandparents ──
                _SectionLabel('GRANDPARENTS'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _AdultTile(
                        role: FamilyRole.grandfather,
                        selected: _quantities[FamilyRole.grandfather]! > 0,
                        onTap: () => _toggleAdult(FamilyRole.grandfather),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AdultTile(
                        role: FamilyRole.grandmother,
                        selected: _quantities[FamilyRole.grandmother]! > 0,
                        onTap: () => _toggleAdult(FamilyRole.grandmother),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Parents ──
                _SectionLabel('PARENTS'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _AdultTile(
                        role: FamilyRole.father,
                        selected: _quantities[FamilyRole.father]! > 0,
                        onTap: () => _toggleAdult(FamilyRole.father),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AdultTile(
                        role: FamilyRole.mother,
                        selected: _quantities[FamilyRole.mother]! > 0,
                        onTap: () => _toggleAdult(FamilyRole.mother),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Kids ──
                _SectionLabel('KIDS'),
                const SizedBox(height: 10),
                _KidTile(
                  role: FamilyRole.son,
                  count: _quantities[FamilyRole.son]!,
                  onIncrement: () => _bumpKid(FamilyRole.son, 1),
                  onDecrement: () => _bumpKid(FamilyRole.son, -1),
                ),
                const SizedBox(height: 12),
                _KidTile(
                  role: FamilyRole.daughter,
                  count: _quantities[FamilyRole.daughter]!,
                  onIncrement: () => _bumpKid(FamilyRole.daughter, 1),
                  onDecrement: () => _bumpKid(FamilyRole.daughter, -1),
                ),
              ],
            ),
            // Floating CTA — anchored to the bottom of the
            // SafeArea so it never overlaps the keyboard or
            // home-indicator. Disabled (greyed out) when the
            // roster is empty so the tap is unambiguous.
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: _GenerateCta(
                count: _totalCount,
                onTap: _totalCount == 0 ? null : _generate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.manrope(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: AppColors.textTertiary,
      ),
    );
  }
}

/// Avatar-style tile for adults — taps once to add, again to
/// remove. Shows the role's icon, label, and a checkmark when
/// selected.
class _AdultTile extends StatelessWidget {
  const _AdultTile({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final FamilyRole role;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    switch (role) {
      case FamilyRole.grandfather:
        return Icons.elderly;
      case FamilyRole.grandmother:
        return Icons.elderly_woman;
      case FamilyRole.father:
      case FamilyRole.male:
        return Icons.man_rounded;
      case FamilyRole.mother:
      case FamilyRole.female:
        return Icons.woman_rounded;
      case FamilyRole.son:
        return Icons.boy_rounded;
      case FamilyRole.daughter:
        return Icons.girl_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.accent
                  : AppColors.primary.withAlpha(20),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accent
                      : AppColors.primary.withAlpha(15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  _icon,
                  size: 28,
                  color: selected ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                role.label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                selected ? 'Added' : 'Tap to add',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  color: selected
                      ? Colors.white.withAlpha(200)
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kid tile with a quantity stepper. Different visual rhythm
/// from adult tiles so a parent reading the page knows kids are
/// the "many of these" row.
class _KidTile extends StatelessWidget {
  const _KidTile({
    required this.role,
    required this.count,
    required this.onIncrement,
    required this.onDecrement,
  });

  final FamilyRole role;
  final int count;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  IconData get _icon =>
      role == FamilyRole.son ? Icons.boy_rounded : Icons.girl_rounded;

  @override
  Widget build(BuildContext context) {
    final selected = count > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withAlpha(8)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? AppColors.accent
              : AppColors.primary.withAlpha(20),
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent
                  : AppColors.primary.withAlpha(15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              _icon,
              size: 28,
              color: selected ? Colors.white : AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role == FamilyRole.son ? 'Sons' : 'Daughters',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count == 0
                      ? 'Tap + to add'
                      : '$count ${count == 1 ? "child" : "children"}',
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // Stepper.
          _StepperButton(icon: Icons.remove, onTap: count > 0 ? onDecrement : null),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _StepperButton(icon: Icons.add, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.primary
                : AppColors.primary.withAlpha(30),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: enabled ? Colors.white : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// Floating "Generate Matching Sets" button. Disabled state is
/// styled distinctly (no shadow, lower contrast) so the user
/// understands they need to add at least one member first.
class _GenerateCta extends StatelessWidget {
  const _GenerateCta({required this.count, required this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.primary
                : AppColors.primary.withAlpha(70),
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(60),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      enabled
                          ? 'Continue · Pick garments'
                          : 'Add at least one member',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
                    ),
                    if (enabled) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$count ${count == 1 ? "member" : "members"} → wizard',
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
