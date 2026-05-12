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

  /// What to render in the right-aligned summary pill — the raw
  /// stored string isn't always pretty (the manual-measurements
  /// case is a long "Custom: chest…, waist…" line that doesn't
  /// fit). Compact it down to a 1-word label so the pill stays
  /// readable.
  String? get _selectedPillLabel {
    if (selected == null) return null;
    if (isManualSize(selected)) return 'Custom';
    if (isTailorVisitSize(selected)) return 'Tailor';
    return selected;
  }

  Future<void> _openManualSheet(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManualMeasurementsSheet(
        memberLabel: spec.label,
        // Pre-fill if the user is editing an existing manual
        // entry — parses the "Custom: chest 38, …" string back
        // into the four fields.
        initial: isManualSize(selected) ? selected : null,
      ),
    );
    if (result != null) onSelect(result);
  }

  /// Push the existing Book Home Tailor form in pop-on-success
  /// mode — the user fills address + date + slot, we INSERT a
  /// `tailor_appointments` row, and the form pops back here with
  /// the appointment id. We then stamp the `kSizeHomeTailor`
  /// sentinel onto this member so the wizard's completion check
  /// passes and the user can continue.
  ///
  /// The Partner app's dispatch radar is subscribed to pending
  /// rows over Supabase Realtime, so the booking request will
  /// surface on every online tailor's phone within a second —
  /// no extra wiring needed here.
  Future<void> _openBookTailor(BuildContext context) async {
    final appointmentId = await context
        .push<String>('/measurements/book-tailor?popOnSuccess=true');
    if (appointmentId != null && appointmentId.isNotEmpty) {
      onSelect(kSizeHomeTailor);
    }
  }

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
              if (_selectedPillLabel != null)
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
                    _selectedPillLabel!,
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
          const SizedBox(height: 12),
          // Soft divider separates "off-the-rack" sizes above from
          // the bespoke alternatives below.
          Container(
            height: 1,
            color: AppColors.primary.withAlpha(15),
          ),
          const SizedBox(height: 12),
          // Two side-by-side alternatives — manual measurements
          // for someone who knows their numbers, home-tailor for
          // someone who'd rather have it taken in person. Each
          // member picks independently so a 6-year-old can have
          // a chart size while their parent picks tailor visit.
          Row(
            children: [
              Expanded(
                child: _AltOption(
                  icon: Icons.edit_note_rounded,
                  label: 'Enter manually',
                  selected: isManualSize(selected),
                  onTap: () => _openManualSheet(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AltOption(
                  icon: Icons.home_repair_service_rounded,
                  label: 'Home tailor',
                  selected: isTailorVisitSize(selected),
                  // Used to just stamp the sentinel locally — now
                  // actually pushes the booking form so a real
                  // `tailor_appointments` row is INSERTed and a
                  // tailor receives the request. See
                  // `_openBookTailor` above.
                  onTap: () => _openBookTailor(context),
                ),
              ),
            ],
          ),
          if (isManualSize(selected)) ...[
            const SizedBox(height: 10),
            Text(
              selected!,
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ] else if (isTailorVisitSize(selected)) ...[
            const SizedBox(height: 10),
            Text(
              'A tailor will visit and take exact measurements before stitching begins.',
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
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
}

/// One of the two off-chart alternatives — visually distinct from
/// the chart-size chips so users read it as "different KIND of
/// option" rather than "another size code".
class _AltOption extends StatelessWidget {
  const _AltOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.primary.withAlpha(35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal sheet that captures four core measurements for a single
/// member. Exact-fit fields are kept short on purpose — chest /
/// waist / length / sleeve cover the vast majority of garments.
/// The atelier refines anything else during the make.
///
/// Returns the encoded "Custom: …" string the size-selection map
/// expects, or null if the user dismissed without saving.
class _ManualMeasurementsSheet extends StatefulWidget {
  const _ManualMeasurementsSheet({
    required this.memberLabel,
    this.initial,
  });

  final String memberLabel;
  final String? initial;

  @override
  State<_ManualMeasurementsSheet> createState() =>
      _ManualMeasurementsSheetState();
}

class _ManualMeasurementsSheetState
    extends State<_ManualMeasurementsSheet> {
  final _chest = TextEditingController();
  final _waist = TextEditingController();
  final _length = TextEditingController();
  final _sleeve = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Re-hydrate from a prior pass so the user can edit a
    // previously-entered set without re-typing every field.
    final prior = widget.initial;
    if (prior != null && isManualSize(prior)) {
      // Strip the prefix and split the comma-list back into the
      // four fields. Format is "Custom: chest 38, waist 32, …";
      // missing fields stay empty rather than throwing.
      final body = prior.substring(kSizeManualPrefix.length);
      for (final part in body.split(',')) {
        final tokens = part.trim().split(' ');
        if (tokens.length < 2) continue;
        final value = tokens.sublist(1).join(' ');
        switch (tokens.first.toLowerCase()) {
          case 'chest':
            _chest.text = value;
          case 'waist':
            _waist.text = value;
          case 'length':
            _length.text = value;
          case 'sleeve':
            _sleeve.text = value;
        }
      }
    }
  }

  @override
  void dispose() {
    _chest.dispose();
    _waist.dispose();
    _length.dispose();
    _sleeve.dispose();
    super.dispose();
  }

  void _save() {
    final parts = <String>[];
    void add(String label, TextEditingController c) {
      final v = c.text.trim();
      if (v.isNotEmpty) parts.add('$label $v');
    }

    add('chest', _chest);
    add('waist', _waist);
    add('length', _length);
    add('sleeve', _sleeve);

    if (parts.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop('$kSizeManualPrefix${parts.join(', ')}');
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              '${widget.memberLabel} · enter measurements',
              style: GoogleFonts.newsreader(
                fontSize: 22,
                fontStyle: FontStyle.italic,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'In inches. Skip any you don\'t know — atelier confirms during the make.',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            _MeasurementRow(label: 'Chest', controller: _chest),
            const SizedBox(height: 12),
            _MeasurementRow(label: 'Waist', controller: _waist),
            const SizedBox(height: 12),
            _MeasurementRow(label: 'Length', controller: _length),
            const SizedBox(height: 12),
            _MeasurementRow(label: 'Sleeve', controller: _sleeve),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Save measurements',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  const _MeasurementRow({
    required this.label,
    required this.controller,
  });

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '0.0',
              hintStyle: GoogleFonts.manrope(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
              filled: true,
              fillColor: AppColors.background,
              suffixText: 'in',
              suffixStyle: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
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
