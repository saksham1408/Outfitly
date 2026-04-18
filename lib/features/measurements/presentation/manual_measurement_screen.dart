import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../../checkout/models/order_payload.dart';
import '../models/body_measurements.dart';

class ManualMeasurementScreen extends StatefulWidget {
  final OrderPayload? payload;

  const ManualMeasurementScreen({super.key, this.payload});

  @override
  State<ManualMeasurementScreen> createState() =>
      _ManualMeasurementScreenState();
}

class _ManualMeasurementScreenState extends State<ManualMeasurementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  // Visual guide icons per measurement
  static const _fieldIcons = <String, IconData>{
    'chest': Icons.expand,
    'waist': Icons.straighten,
    'shoulder': Icons.open_with_rounded,
    'sleeve_length': Icons.swap_horiz,
    'shirt_length': Icons.height,
    'neck': Icons.circle_outlined,
    'trouser_waist': Icons.straighten,
    'hip': Icons.expand,
    'thigh': Icons.swap_vert,
    'inseam': Icons.height,
    'trouser_length': Icons.height,
  };

  static const _fieldHints = <String, String>{
    'chest': 'Measure around the fullest part',
    'waist': 'Measure at the natural waistline',
    'shoulder': 'Measure from edge to edge',
    'sleeve_length': 'Shoulder seam to wrist',
    'shirt_length': 'Back of neck to hem',
    'neck': 'Base of neck, leave finger gap',
    'trouser_waist': 'Where you wear your trousers',
    'hip': 'Widest part of the hips',
    'thigh': 'Widest point of upper leg',
    'inseam': 'Inner leg, crotch to ankle',
    'trouser_length': 'Waist to ankle bone',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    for (final field in [...upperBodyFields, ...lowerBodyFields]) {
      _controllers[field.key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      // Build measurements map
      final measurementData = <String, double>{};
      final dbData = <String, dynamic>{'user_id': user.id};

      for (final entry in _controllers.entries) {
        final value = entry.value.text.trim();
        if (value.isNotEmpty) {
          final parsed = double.tryParse(value);
          if (parsed != null) {
            measurementData[entry.key] = parsed;
            dbData[entry.key] = parsed;
          }
        }
      }

      // Save to Supabase (onConflict handles existing row for this user)
      await AppSupabase.client
          .from('measurements')
          .upsert(dbData, onConflict: 'user_id');

      // Pass measurements to payload
      final payload = widget.payload;
      if (payload != null) {
        payload.measurementMethod = 'manual';
        payload.measurements = measurementData;
      }

      if (!mounted) return;

      // Navigate to checkout
      if (payload != null) {
        context.push('/cart', extra: payload);
      } else {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Measurements saved!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save. Please try again.')),
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
          'Enter Measurements',
          style: GoogleFonts.newsreader(
            fontSize: 22,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.accent,
          indicatorWeight: 2.5,
          labelStyle: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'UPPER BODY'),
            Tab(text: 'LOWER BODY'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildFieldsList(upperBodyFields),
            _buildFieldsList(lowerBodyFields),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'All measurements in inches. Leave blank if unsure.',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
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
                          widget.payload != null
                              ? 'SAVE & CONTINUE TO CHECKOUT'
                              : 'SAVE MEASUREMENTS',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
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

  Widget _buildFieldsList(List<MeasurementField> fields) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: fields.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final field = fields[index];
        final controller = _controllers[field.key]!;
        final icon = _fieldIcons[field.key] ?? Icons.straighten;
        final hint = _fieldHints[field.key] ?? '';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border.withAlpha(50)),
          ),
          child: Row(
            children: [
              // Visual guide icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              // Field info + input
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.label,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      hint,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // Input
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  decoration: InputDecoration(
                    hintText: field.hint,
                    hintStyle: GoogleFonts.manrope(
                      color: AppColors.border,
                      fontSize: 14,
                    ),
                    suffixText: '"',
                    suffixStyle: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceContainer,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
