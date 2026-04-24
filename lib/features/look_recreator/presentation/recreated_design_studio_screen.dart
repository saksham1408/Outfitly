import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../../design_studio/models/customization_options.dart';
import '../models/recreated_design.dart';

/// Step 4 — the "design studio variation" the user lands on after
/// Gemini has reverse-engineered the inspiration photo.
///
/// This is intentionally a **sister** of `DesignStudioScreen`, not a
/// fork: the canonical studio is bound to a specific catalog product
/// (`productId` in the constructor) and pulls fabric options from
/// that product's row. The AI flow has no anchor product — Gemini
/// suggests a fabric in free text — so we render a parallel surface
/// that:
///
///   * Mirrors the studio's visual language (label/value rows, the
///     same option labels) so the user doesn't feel transplanted.
///   * Pre-selects the AI's collar / sleeve / fit IDs and renders
///     the canonical labels from `customization_options.dart`.
///   * Surfaces the AI's free-text fabric and stylist notes at the
///     top so the user understands the choices they're seeing.
///   * Shows the AI-estimated price and offers a continue path into
///     the existing custom-clothing flow.
///
/// Tweaking is intentionally lightweight here — tap a row to cycle
/// through the canonical options for that step. Anything more
/// sophisticated (multi-photo refs, fabric swatches) can be layered
/// in later without changing this entry surface.
class RecreatedDesignStudioScreen extends StatefulWidget {
  const RecreatedDesignStudioScreen({super.key, required this.result});

  final RecreatedDesignResult result;

  @override
  State<RecreatedDesignStudioScreen> createState() =>
      _RecreatedDesignStudioScreenState();
}

/// Carrier for the (image, design) tuple handed to the result screen
/// via `state.extra`. The image is shown alongside the recreated
/// specs so the user can see "what they uploaded" vs "what we built"
/// side-by-side.
class RecreatedDesignResult {
  const RecreatedDesignResult({
    required this.image,
    required this.design,
  });

  final File image;
  final RecreatedDesign design;
}

class _RecreatedDesignStudioScreenState
    extends State<RecreatedDesignStudioScreen> {
  late String _collarId;
  late String _sleeveId;
  late String _fitId;
  late int _price;

  @override
  void initState() {
    super.initState();
    _collarId = widget.result.design.collarStyle;
    _sleeveId = widget.result.design.sleeveDesign;
    _fitId    = widget.result.design.fitType;
    _price    = widget.result.design.estimatedPrice;
  }

  /// Cycle to the next option in [step] for the current value.
  /// Wraps around so the user can always re-select the AI's pick.
  String _cycleNext(CustomizationStep step, String currentId) {
    final ids = step.options.map((o) => o.id).toList();
    if (ids.isEmpty) return currentId;
    final i = ids.indexOf(currentId);
    if (i == -1) return ids.first;
    return ids[(i + 1) % ids.length];
  }

  String _labelFor(CustomizationStep step, String id) {
    return step.options
        .firstWhere(
          (o) => o.id == id,
          orElse: () => step.options.first,
        )
        .label;
  }

  @override
  Widget build(BuildContext context) {
    final design = widget.result.design;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Your Recreated Look',
          style: GoogleFonts.newsreader(
            fontSize: 22,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StylistNotesCard(notes: design.stylistNotes),
            const SizedBox(height: 20),
            _InspirationStrip(image: widget.result.image),
            const SizedBox(height: 24),

            _SectionLabel('SUGGESTED FABRIC'),
            const SizedBox(height: 10),
            _FabricCard(fabric: design.fabricType),
            const SizedBox(height: 24),

            _SectionLabel('GARMENT SPECS'),
            const SizedBox(height: 10),
            _OptionRow(
              label: 'Collar',
              value: _labelFor(collarOptions, _collarId),
              onTap: () => setState(
                () => _collarId = _cycleNext(collarOptions, _collarId),
              ),
            ),
            const SizedBox(height: 10),
            _OptionRow(
              label: 'Sleeves',
              value: _labelFor(sleeveOptions, _sleeveId),
              onTap: () => setState(
                () => _sleeveId = _cycleNext(sleeveOptions, _sleeveId),
              ),
            ),
            const SizedBox(height: 10),
            _OptionRow(
              label: 'Fit',
              value: _labelFor(fitOptions, _fitId),
              onTap: () => setState(
                () => _fitId = _cycleNext(fitOptions, _fitId),
              ),
            ),
            const SizedBox(height: 28),

            _SectionLabel('AI-ESTIMATED PRICE'),
            const SizedBox(height: 10),
            _PriceCard(price: _price),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Hand off to the manual measurement flow — the
                    // existing checkout path is product-anchored and
                    // doesn't yet take a "free-form" recreated design.
                    // Wiring that end-to-end is a follow-up; for now
                    // we route into the measurements decision screen
                    // so the user can at least secure their fit data
                    // while we finish the stitching pipeline.
                    context.push('/measurements/decision');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'CONTINUE TO MEASUREMENTS',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => context.pushReplacement('/recreate-look'),
                  child: Text(
                    'TRY ANOTHER PHOTO',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppColors.textSecondary,
                    ),
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

// ────────────────────────────────────────────────────────────
// Stylist notes — first card the user reads
// ────────────────────────────────────────────────────────────
class _StylistNotesCard extends StatelessWidget {
  const _StylistNotesCard({required this.notes});
  final String notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome,
                size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STYLIST NOTES',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  notes,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Inspiration strip — small thumbnail of what the user uploaded
// ────────────────────────────────────────────────────────────
class _InspirationStrip extends StatelessWidget {
  const _InspirationStrip({required this.image});
  final File image;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            image,
            width: 64,
            height: 84,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'INSPIRATION',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Decoded into a custom blueprint below.',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
// Fabric card — Gemini's free-text suggestion
// ────────────────────────────────────────────────────────────
class _FabricCard extends StatelessWidget {
  const _FabricCard({required this.fabric});
  final String fabric;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.layers_outlined,
              color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fabric,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accentContainer.withAlpha(50),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'AI PICK',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Generic option row — tap to cycle
// ────────────────────────────────────────────────────────────
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.unfold_more,
                color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Price card — the AI's INR estimate
// ────────────────────────────────────────────────────────────
class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.price});
  final int price;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated price',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: Colors.white.withAlpha(170),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${_formatInr(price)}',
                  style: GoogleFonts.newsreader(
                    fontSize: 32,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stitching, fabric, and home delivery included.',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: Colors.white.withAlpha(170),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.auto_awesome,
              color: AppColors.accentContainer, size: 28),
        ],
      ),
    );
  }

  /// Naive Indian-numbering grouping (lakh / crore) — `123456` →
  /// `1,23,456`. Good enough for a price card; we don't pull in the
  /// `intl` package just for this.
  String _formatInr(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final restGrouped = rest
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+$)'), (m) => '${m[1]},');
    return '$restGrouped,$last3';
  }
}

// ────────────────────────────────────────────────────────────
// Section label
// ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: AppColors.textTertiary,
      ),
    );
  }
}
