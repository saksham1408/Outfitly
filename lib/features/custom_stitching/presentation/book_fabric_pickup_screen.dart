import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../data/custom_stitching_repository.dart';
import '../models/custom_stitch_order.dart';

/// "Book New Pickup" — a single-screen booking form for the
/// Stitch My Fabric service. Three logical steps stacked
/// vertically on one scrollable card so the user can scan the
/// whole booking before committing:
///
///   A. What do you want stitched?  (garment-type grid)
///   B. Reference design (optional)  (image picker, gallery only)
///   C. Pickup window                (date + time picker)
///
/// On submit we INSERT a `custom_stitch_orders` row via
/// [CustomStitchingRepository.bookPickup], which uploads the
/// reference image to the Storage bucket first if one was picked.
/// The screen then pops back to the dashboard, which re-paints
/// from the repository's [ValueNotifier] cache without another
/// round-trip.
class BookFabricPickupScreen extends StatefulWidget {
  const BookFabricPickupScreen({super.key});

  @override
  State<BookFabricPickupScreen> createState() =>
      _BookFabricPickupScreenState();
}

class _BookFabricPickupScreenState extends State<BookFabricPickupScreen> {
  final _addressController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _selectedGarment;
  XFile? _referenceImage;
  DateTime? _pickupDate;
  TimeOfDay? _pickupTime;
  bool _submitting = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _selectedGarment != null &&
      _pickupDate != null &&
      _pickupTime != null &&
      _addressController.text.trim().isNotEmpty;

  Future<void> _pickReferenceImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _referenceImage = picked);
    } catch (e) {
      _showSnack('Couldn\'t open the gallery — $e');
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // Earliest pickup is tomorrow (atelier needs a day's notice);
    // window of 30 days felt about right for MVP — far enough to
    // cover wedding planning, near enough that the calendar grid
    // stays scannable.
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickupDate ?? now.add(const Duration(days: 1)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 30)),
      helpText: 'Pick a pickup date',
    );
    if (picked != null) setState(() => _pickupDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _pickupTime ?? const TimeOfDay(hour: 11, minute: 0),
      helpText: 'Pick a pickup window',
    );
    if (picked != null) setState(() => _pickupTime = picked);
  }

  /// Combine the date + time pickers into a single DateTime
  /// stored as the row's `pickup_time`.
  DateTime? get _scheduledAt {
    final d = _pickupDate;
    final t = _pickupTime;
    if (d == null || t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;

    final user = AppSupabase.client.auth.currentUser;
    if (user == null) {
      _showSnack('Please sign in again to book a pickup.');
      return;
    }

    setState(() => _submitting = true);

    final order = CustomStitchOrder(
      id: '', // server-generated — ignored by toInsertRow
      userId: user.id,
      garmentType: _selectedGarment!,
      pickupAddress: _addressController.text.trim(),
      pickupTime: _scheduledAt!,
      status: CustomStitchStatus.pendingPickup,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await CustomStitchingRepository.instance.bookPickup(
        order,
        referenceImage:
            _referenceImage != null ? File(_referenceImage!.path) : null,
      );
      if (!mounted) return;
      _showSnack('Pickup booked — your tailor will reach out soon.');
      // Pop back to the dashboard. The repository's ValueNotifier
      // already has the new row spliced in, so the timeline card
      // appears without a manual refetch.
      context.pop();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Booking failed — $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.manrope(fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
      ),
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
          'Book Fabric Pickup',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Text(
              'Doorstep Tailor',
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
              'We\'ll send a tailor to your home to take measurements and pick up your fabric.',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),

            // ── Step A · Garment type ─────────────────────────
            _StepHeader(
              index: 'A',
              title: 'What do you want us to stitch?',
              subtitle: 'Pick the silhouette you want made.',
            ),
            const SizedBox(height: 12),
            _GarmentGrid(
              selected: _selectedGarment,
              onSelect: (g) => setState(() => _selectedGarment = g),
            ),
            const SizedBox(height: 28),

            // ── Step B · Reference image ─────────────────────
            _StepHeader(
              index: 'B',
              title: 'Upload a reference design',
              subtitle:
                  'Optional — share a photo so the tailor knows the look.',
            ),
            const SizedBox(height: 12),
            _ReferenceImageTile(
              file: _referenceImage,
              onPick: _pickReferenceImage,
              onClear: () => setState(() => _referenceImage = null),
            ),
            const SizedBox(height: 28),

            // ── Step C · Date + time + address ────────────────
            _StepHeader(
              index: 'C',
              title: 'When + where?',
              subtitle:
                  'Pick a slot that works for you — and the address we\'ll visit.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.calendar_today_rounded,
                    label: _pickupDate == null
                        ? 'Pickup date'
                        : DateFormat('EEE, d MMM').format(_pickupDate!),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.schedule_rounded,
                    label: _pickupTime == null
                        ? 'Pickup time'
                        : _pickupTime!.format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              minLines: 2,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText:
                    'Pickup address — flat / building / area / city',
                hintStyle: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.primary.withAlpha(30)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.primary.withAlpha(30)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _ConfirmCta(
        enabled: _isValid && !_submitting,
        loading: _submitting,
        onTap: _submit,
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ────────────────────────────────────────────────────────────
// Sub-widgets
// ────────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.index,
    required this.title,
    required this.subtitle,
  });

  final String index;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            index,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(width: 12),
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

class _GarmentGrid extends StatelessWidget {
  const _GarmentGrid({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final g in kCustomStitchGarmentTypes)
          _GarmentChip(
            label: g,
            selected: selected == g,
            onTap: () => onSelect(g),
          ),
      ],
    );
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
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
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

class _ReferenceImageTile extends StatelessWidget {
  const _ReferenceImageTile({
    required this.file,
    required this.onPick,
    required this.onClear,
  });

  final XFile? file;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (file == null) {
      return InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 130,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withAlpha(35),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_outlined,
                size: 26,
                color: AppColors.primary.withAlpha(140),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to add a reference photo',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'JPG / PNG · optional',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            File(file!.path),
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.black.withAlpha(140),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onClear,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.primary.withAlpha(30),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmCta extends StatelessWidget {
  const _ConfirmCta({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: Material(
          color: enabled
              ? AppColors.primary
              : AppColors.primary.withAlpha(80),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : Text(
                      'Confirm Tailor Visit',
                      style: GoogleFonts.manrope(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
