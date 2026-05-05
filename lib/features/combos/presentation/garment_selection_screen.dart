import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../models/combo_catalog.dart';
import '../models/combo_draft.dart';
import '../models/family_member.dart';
import 'combo_wizard_widgets.dart';

/// Step 1 of 3 in the combo customization wizard.
///
/// The user picks one garment type per *role* in the roster
/// (not per member). All sons share a kurta-vs-shirt choice;
/// all daughters share a lehenga-vs-anarkali choice. Adults
/// each have their own role and pick independently.
///
/// On entry: [ComboDraft] from the previous step (Couple
/// shortcut or family builder).
/// On continue: pushes /combos/fabric with the same draft +
/// the populated garmentByRole map.
class GarmentSelectionScreen extends StatefulWidget {
  const GarmentSelectionScreen({super.key, required this.draft});

  final ComboDraft draft;

  @override
  State<GarmentSelectionScreen> createState() =>
      _GarmentSelectionScreenState();
}

class _GarmentSelectionScreenState extends State<GarmentSelectionScreen> {
  late Map<FamilyRole, String> _selections;

  @override
  void initState() {
    super.initState();
    // Pre-fill from any prior pass through the wizard so the
    // user can hit Back, change something, and not lose their
    // earlier picks. Default empty map otherwise.
    _selections = Map<FamilyRole, String>.from(widget.draft.garmentByRole);
  }

  /// Unique roles in the order they appear in the roster.
  /// Multiple kids of the same role collapse to one card.
  List<FamilyRole> get _uniqueRoles {
    final seen = <FamilyRole>{};
    final ordered = <FamilyRole>[];
    for (final m in widget.draft.roster) {
      if (seen.add(m.role)) ordered.add(m.role);
    }
    return ordered;
  }

  void _select(FamilyRole role, String garment) {
    setState(() => _selections[role] = garment);
  }

  bool get _isComplete =>
      _uniqueRoles.every(_selections.containsKey);

  void _continue() {
    final next = widget.draft.copyWith(garmentByRole: _selections);
    context.push('/combos/fabric', extra: next);
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
          'Garments',
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
            const ComboWizardSteps(currentStep: 0),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                children: [
                  Text(
                    'Pick the silhouette',
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
                    'One garment per family member type — siblings of the same role share the same look.',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),

                  for (final role in _uniqueRoles) ...[
                    _RoleGarmentCard(
                      role: role,
                      options:
                          kGarmentsByRole[role] ?? const <String>[],
                      selected: _selections[role],
                      onSelect: (g) => _select(role, g),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ComboWizardFooter(
        primary: 'Continue · Pick a fabric',
        secondary: _isComplete
            ? 'Tailored looks across the roster'
            : 'Pick one garment per member to continue',
        enabled: _isComplete,
        onTap: _continue,
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
    );
  }
}

/// One per-role card. Header (role name + tagline), then a
/// horizontal-wrap chip row of garment options.
class _RoleGarmentCard extends StatelessWidget {
  const _RoleGarmentCard({
    required this.role,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final FamilyRole role;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                  _iconFor(role),
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  role.label,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (selected != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(40),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    selected!,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                _GarmentChip(
                  label: option,
                  selected: selected == option,
                  onTap: () => onSelect(option),
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

class _GarmentChip extends StatelessWidget {
  const _GarmentChip({
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
