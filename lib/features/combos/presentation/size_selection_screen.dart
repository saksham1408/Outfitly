import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../models/combo_catalog.dart';
import '../models/combo_draft.dart';
import '../models/family_member.dart';
import 'combo_wizard_widgets.dart';

/// Step 3 of 3 — pick a size for every member of the roster.
///
/// Unlike the garment screen this is per-*member*, not per-role:
/// two sons can be different ages, and a 6-year-old + a
/// 10-year-old need different cuts even if they share the same
/// "Mini Kurta" silhouette. The expanded roster gives us one
/// row per child.
///
/// Adults pick from S/M/L/XL/XXL; kids pick age ranges.
class SizeSelectionScreen extends StatefulWidget {
  const SizeSelectionScreen({super.key, required this.draft});

  final ComboDraft draft;

  @override
  State<SizeSelectionScreen> createState() =>
      _SizeSelectionScreenState();
}

class _SizeSelectionScreenState extends State<SizeSelectionScreen> {
  late Map<int, String> _sizes;

  @override
  void initState() {
    super.initState();
    _sizes = Map<int, String>.from(widget.draft.sizeByMemberIndex);
  }

  void _select(int index, String size) {
    setState(() => _sizes[index] = size);
  }

  bool get _isComplete {
    final expected = widget.draft.expandedRoster.length;
    return _sizes.length == expected &&
        List.generate(expected, (i) => i).every(_sizes.containsKey);
  }

  void _generate() {
    final next = widget.draft.copyWith(sizeByMemberIndex: _sizes);
    context.push('/combos/results', extra: next);
  }

  @override
  Widget build(BuildContext context) {
    // Index siblings of the same role so the cards read e.g.
    // "Son #1", "Son #2" — saves the customer from having to
    // re-count which child each row is for.
    final expanded = widget.draft.expandedRoster;
    final roleCounts = <FamilyRole, int>{};
    final cards = <_SizeCardSpec>[];
    final totalByRole = <FamilyRole, int>{};
    for (final r in expanded) {
      totalByRole[r] = (totalByRole[r] ?? 0) + 1;
    }
    for (var i = 0; i < expanded.length; i++) {
      final role = expanded[i];
      final n = (roleCounts[role] ?? 0) + 1;
      roleCounts[role] = n;
      final showIndex = (totalByRole[role] ?? 0) > 1;
      cards.add(_SizeCardSpec(
        index: i,
        role: role,
        label: showIndex ? '${role.label} #$n' : role.label,
      ));
    }

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
          'Sizes',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const ComboWizardSteps(currentStep: 2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                children: [
                  Text(
                    'Pick a size for each',
                    style: GoogleFonts.newsreader(
                      fontSize: 26,
                      fontStyle: FontStyle.italic,
                      color: AppColors.primary,
                      height: 1.1,
                    ),
                  ),
                  Container(
                    height: 2,
                    width: 56,
                    margin: const EdgeInsets.only(top: 6),
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Adults pick S → XXL. Kids pick by age range — measurements get refined at the home tailor visit.',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),

                  for (final spec in cards) ...[
                    _MemberSizeCard(
                      spec: spec,
                      selected: _sizes[spec.index],
                      onSelect: (s) => _select(spec.index, s),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ComboWizardFooter(
        primary: 'Generate Matching Sets',
        secondary: _isComplete
            ? 'Searching coordinated looks for ${cards.length} ${cards.length == 1 ? "person" : "people"}'
            : 'Pick a size for every member',
        enabled: _isComplete,
        onTap: _generate,
        icon: Icons.auto_awesome_rounded,
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _SizeCardSpec {
  const _SizeCardSpec({
    required this.index,
    required this.role,
    required this.label,
  });

  final int index;
  final FamilyRole role;
  final String label;
}

class _MemberSizeCard extends StatelessWidget {
  const _MemberSizeCard({
    required this.spec,
    required this.selected,
    required this.onSelect,
  });

  final _SizeCardSpec spec;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final options = spec.role.isChild ? kKidSizes : kAdultSizes;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _iconFor(spec.role),
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  spec.label,
                  style: GoogleFonts.manrope(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (selected != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    selected!,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final size in options)
                _SizeChip(
                  label: size,
                  selected: selected == size,
                  onTap: () => onSelect(size),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(FamilyRole role) {
    switch (role) {
      case FamilyRole.grandfather:
        return Icons.elderly;
      case FamilyRole.grandmother:
        return Icons.elderly_woman;
      case FamilyRole.father:
        return Icons.man_rounded;
      case FamilyRole.mother:
        return Icons.woman_rounded;
      case FamilyRole.son:
        return Icons.boy_rounded;
      case FamilyRole.daughter:
        return Icons.girl_rounded;
    }
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.primary.withAlpha(35),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
