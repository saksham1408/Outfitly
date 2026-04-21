import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../../core/theme/theme.dart';
import '../../models/measurement_profile.dart';
import 'ai_scanning_screen.dart';

/// Final step of the AI Body Scan flow.
///
/// Shows every measurement as a row the user can tap to nudge up or
/// down (for a looser or tighter fit). On submit we:
///   1. Upsert the full set into the `measurements` Supabase table,
///   2. Write the same map into the [OrderPayload.measurements], and
///   3. Push `/cart` so the user continues straight into checkout.
class AiMeasurementReviewScreen extends StatefulWidget {
  final AiReviewPayload payload;

  const AiMeasurementReviewScreen({super.key, required this.payload});

  @override
  State<AiMeasurementReviewScreen> createState() =>
      _AiMeasurementReviewScreenState();
}

class _AiMeasurementReviewScreenState extends State<AiMeasurementReviewScreen> {
  late MeasurementProfile _profile;
  bool _saving = false;

  static const _rows = <_MeasurementRow>[
    _MeasurementRow('chest', 'Chest', Icons.expand, 'Around the fullest part'),
    _MeasurementRow('waist', 'Waist', Icons.straighten, 'Natural waistline'),
    _MeasurementRow(
        'shoulder', 'Shoulder', Icons.open_with_rounded, 'Edge to edge'),
    _MeasurementRow('sleeve_length', 'Sleeve Length', Icons.swap_horiz,
        'Shoulder to wrist'),
    _MeasurementRow(
        'shirt_length', 'Shirt Length', Icons.height, 'Neck to hem'),
    _MeasurementRow('neck', 'Neck', Icons.circle_outlined, 'Base of neck'),
    _MeasurementRow(
        'trouser_waist', 'Trouser Waist', Icons.straighten, 'Where you wear them'),
    _MeasurementRow('hip', 'Hip', Icons.expand, 'Widest point'),
    _MeasurementRow('thigh', 'Thigh', Icons.swap_vert, 'Widest point of leg'),
    _MeasurementRow(
        'inseam', 'Inseam', Icons.height, 'Crotch to ankle'),
    _MeasurementRow(
        'trouser_length', 'Trouser Length', Icons.height, 'Waist to ankle'),
  ];

  @override
  void initState() {
    super.initState();
    _profile = widget.payload.profile;
  }

  double _valueFor(String key) => _profile.toMap()[key] ?? 0;

  void _setValue(String key, double next) {
    // Clamp to a sane human range so the stepper can't go wild.
    final clamped = next.clamp(5, 80).toDouble();
    setState(() {
      _profile = _profile.copyWith(
        chest: key == 'chest' ? clamped : null,
        waist: key == 'waist' ? clamped : null,
        shoulder: key == 'shoulder' ? clamped : null,
        sleeveLength: key == 'sleeve_length' ? clamped : null,
        shirtLength: key == 'shirt_length' ? clamped : null,
        neck: key == 'neck' ? clamped : null,
        trouserWaist: key == 'trouser_waist' ? clamped : null,
        hip: key == 'hip' ? clamped : null,
        thigh: key == 'thigh' ? clamped : null,
        inseam: key == 'inseam' ? clamped : null,
        trouserLength: key == 'trouser_length' ? clamped : null,
      );
    });
  }

  Future<void> _openAdjustSheet(_MeasurementRow row) async {
    double temp = _valueFor(row.key);
    final updated = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(row.icon,
                          size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Adjust ${row.label}',
                            style: GoogleFonts.newsreader(
                              fontSize: 20,
                              fontStyle: FontStyle.italic,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            row.hint,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _stepperButton(Icons.remove, () {
                      setSheet(() => temp = (temp - 0.5).clamp(5, 80));
                    }),
                    const SizedBox(width: 24),
                    Column(
                      children: [
                        Text(
                          temp.toStringAsFixed(1),
                          style: GoogleFonts.newsreader(
                            fontSize: 54,
                            fontStyle: FontStyle.italic,
                            color: AppColors.primary,
                            height: 1,
                          ),
                        ),
                        Text(
                          'inches',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    _stepperButton(Icons.add, () {
                      setSheet(() => temp = (temp + 0.5).clamp(5, 80));
                    }),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: AppColors.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nudge up for a looser fit, down for tighter. 0.5" at a time.',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.accent,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(temp),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'UPDATE',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );

    if (updated != null) _setValue(row.key, updated);
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(12),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary.withAlpha(40)),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }

  Future<void> _saveAndContinue() async {
    setState(() => _saving = true);
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) {
        throw StateError('You must be signed in to save measurements.');
      }

      final measurements = _profile.toMap();
      final dbData = <String, dynamic>{'user_id': user.id, ...measurements};

      await AppSupabase.client
          .from('measurements')
          .upsert(dbData, onConflict: 'user_id');

      final payload = widget.payload.order;
      if (payload != null) {
        payload.measurementMethod = 'ai_scan';
        payload.measurements = measurements;
      }

      if (!mounted) return;

      if (payload != null) {
        context.pushReplacement('/cart', extra: payload);
      } else {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Measurements saved!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Review Measurements',
          style: GoogleFonts.newsreader(
            fontSize: 22,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  // ── Success banner ──
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primaryDark,
                          AppColors.primary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.success.withAlpha(220),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scan complete',
                                style: GoogleFonts.newsreader(
                                  fontSize: 20,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Tap any row to nudge it — looser or tighter.',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: Colors.white.withAlpha(200),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  Text(
                    'YOUR MEASUREMENTS',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  ..._rows.map(_buildRow),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'All measurements in inches. Tap a row to fine-tune.',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveAndContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'SAVE & CONTINUE TO CHECKOUT',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(_MeasurementRow row) {
    final value = _valueFor(row.key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openAdjustSheet(row),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border.withAlpha(60)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(row.icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.label,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      row.hint,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text(
                      value.toStringAsFixed(1),
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '"',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeasurementRow {
  final String key;
  final String label;
  final IconData icon;
  final String hint;
  const _MeasurementRow(this.key, this.label, this.icon, this.hint);
}
