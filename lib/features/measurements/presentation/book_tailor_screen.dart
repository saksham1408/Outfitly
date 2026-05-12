import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../../checkout/models/order_payload.dart';
import '../data/tailor_appointment_service.dart';

class BookTailorScreen extends StatefulWidget {
  final OrderPayload? payload;

  /// When true, the standalone success path **pops back** with the
  /// new appointment id instead of pushReplacing the live tracker.
  /// Used by the Family Combos size step, where the user is
  /// mid-wizard — we want them to land back on the size screen
  /// (sentinel now set) rather than getting kicked off into a
  /// separate live-visit tracker. Defaults to the existing
  /// behaviour (push the tracker) for every other caller.
  final bool popOnSuccess;

  const BookTailorScreen({
    super.key,
    this.payload,
    this.popOnSuccess = false,
  });

  @override
  State<BookTailorScreen> createState() => _BookTailorScreenState();
}

class _BookTailorScreenState extends State<BookTailorScreen> {
  final _addressController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _pincodeController = TextEditingController();

  String? _selectedDate;
  // Raw DateTime backing the selected date chip. We keep [_selectedDate]
  // as a display string (used by the order-checkout integration via
  // `OrderPayload.tailorDate`) AND this raw value so the standalone
  // "request a tailor visit" path can INSERT a real timestamp into
  // `tailor_appointments` without having to round-trip through the
  // formatted string.
  DateTime? _selectedDateRaw;
  String? _selectedSlot;

  /// Are we submitting the standalone visit request? Disables the CTA
  /// while the Supabase round-trip is in flight so double-taps can't
  /// create duplicate pending rows.
  bool _submitting = false;

  final _service = TailorAppointmentService();

  static const _timeSlots = [
    '10:00 AM – 12:00 PM',
    '12:00 PM – 2:00 PM',
    '2:00 PM – 4:00 PM',
    '4:00 PM – 6:00 PM',
    '6:00 PM – 8:00 PM',
  ];

  List<DateTime> get _availableDates {
    final today = DateTime.now();
    return List.generate(7, (i) => today.add(Duration(days: i + 1)));
  }

  String _formatDate(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }

  bool get _canProceed =>
      _addressController.text.trim().isNotEmpty &&
      _pincodeController.text.trim().length == 6 &&
      _selectedDate != null &&
      _selectedSlot != null &&
      !_submitting;

  /// Combine the selected date chip and time-slot string into a real
  /// [DateTime]. Slot strings look like `"10:00 AM – 12:00 PM"` — we
  /// take the start time. Returns null if parsing fails, so the
  /// caller can fall back gracefully.
  DateTime? _composeScheduledTime() {
    final date = _selectedDateRaw;
    final slot = _selectedSlot;
    if (date == null || slot == null) return null;

    try {
      // Split on the en-dash separator; trim; expect `"h:mm AM|PM"`.
      final start = slot.split('–').first.trim();
      final parts = start.split(' ');
      final hm = parts[0].split(':');
      var hour = int.parse(hm[0]);
      final min = int.parse(hm[1]);
      final isPm = parts[1].toUpperCase() == 'PM';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return DateTime(date.year, date.month, date.day, hour, min);
    } catch (_) {
      return null;
    }
  }

  Future<void> _proceed() async {
    final payload = widget.payload;

    final fullAddress =
        '${_addressController.text.trim()}, ${_landmarkController.text.trim()} — ${_pincodeController.text.trim()}'
            .trimRight();

    if (payload != null) {
      // Marketplace flow: stuff the booking-form values into the
      // payload, then route to the tailor selection screen instead
      // of jumping straight to /cart. The selection screen will
      // assign `tailorId` + `tailorName` and only then push the
      // payload through to /cart for the final review step.
      //
      // The cart's existing `_placeOrder` reads `tailorScheduledTime`
      // (set just below) to INSERT the `tailor_appointments` row —
      // it now also picks up the chosen `tailorId` from the payload
      // and bakes it into the row at creation time, so the chosen
      // tailor (and only that tailor) sees the new request.
      payload.measurementMethod = 'tailor';
      payload.tailorAddress =
          '${_addressController.text.trim()}, ${_landmarkController.text.trim()}'.trimRight();
      payload.tailorPincode = _pincodeController.text.trim();
      payload.tailorDate = _selectedDate;
      payload.tailorTimeSlot = _selectedSlot;
      payload.tailorScheduledTime = _composeScheduledTime();

      context.push('/measurements/select-tailor', extra: payload);
      return;
    }

    // Standalone path — the customer came straight from the home CTA,
    // not from a product checkout. INSERT a `tailor_appointments` row
    // so the Partner app's dispatch radar lights up in real time.
    final scheduled = _composeScheduledTime();
    if (scheduled == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a date and time slot.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final appointmentId = await _service.requestVisit(
        address: fullAddress,
        scheduledTime: scheduled,
      );
      if (!mounted) return;

      if (widget.popOnSuccess) {
        // Mid-wizard caller (e.g. Family Combos size step). Pop
        // back with the appointment id + a short snackbar so the
        // user knows the request landed and can continue picking
        // the rest of their roster's sizes.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Tailor visit requested — a tailor will reach out to confirm.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
        context.pop(appointmentId);
        return;
      }

      // Default path (standalone CTA). Swap this booking form for
      // the live tracker. `pushReplacement` (not `push`) keeps the
      // back gesture from dropping the customer back into a stale,
      // already-submitted form — the tracker is the authoritative
      // "where does this live now" surface.
      //
      // The tracker's "Finding a tailor near you…" hero doubles as
      // the submission-confirmation beat we used to get from a
      // modal, so we don't need an extra dialog here.
      context.pushReplacement('/tailor-visit/$appointmentId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not request visit: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _landmarkController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Book Home Tailor',
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
            // ── Info Banner ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent.withAlpha(30)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined,
                      color: AppColors.accent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'A professional tailor will visit your home to take accurate measurements. This service is free for all orders.',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.accent,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Address Section ──
            _sectionLabel('YOUR ADDRESS'),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              maxLines: 2,
              style: GoogleFonts.manrope(fontSize: 15),
              decoration: _inputDecoration(
                'Flat / House no., Building, Street',
                Icons.home_outlined,
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _landmarkController,
                    style: GoogleFonts.manrope(fontSize: 15),
                    decoration: _inputDecoration('Landmark (optional)', null),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.manrope(fontSize: 15),
                    decoration:
                        _inputDecoration('Pincode', null).copyWith(counterText: ''),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Date Selection ──
            _sectionLabel('PICK A DATE'),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _availableDates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final date = _availableDates[index];
                  final formatted = _formatDate(date);
                  final isSelected = _selectedDate == formatted;
                  final dayName = formatted.split(',').first;

                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedDate = formatted;
                      _selectedDateRaw = date;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 68,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withAlpha(30),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayName,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white.withAlpha(180)
                                  : AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${date.day}',
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            // ── Time Slot Grid ──
            _sectionLabel('PICK A TIME SLOT'),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 3.2,
              ),
              itemCount: _timeSlots.length,
              itemBuilder: (context, index) {
                final slot = _timeSlots[index];
                final isSelected = _selectedSlot == slot;

                return GestureDetector(
                  onTap: () => setState(() => _selectedSlot = slot),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        slot,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canProceed ? _proceed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border.withAlpha(80),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.payload != null
                          ? 'CONTINUE TO CHECKOUT'
                          : 'REQUEST TAILOR VISIT',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
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

  InputDecoration _inputDecoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.manrope(color: AppColors.textTertiary, fontSize: 14),
      prefixIcon: icon != null
          ? Icon(icon, size: 20, color: AppColors.textTertiary)
          : null,
      filled: true,
      fillColor: AppColors.surfaceContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
