import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/locale/money.dart';
import '../../core/network/supabase_client.dart';
import '../../core/theme/theme.dart';
import '../measurements/data/tailor_appointment_service.dart';
import 'models/order_payload.dart';

class CartScreen extends StatefulWidget {
  final OrderPayload? payload;

  const CartScreen({super.key, this.payload});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _placing = false;

  Future<void> _placeOrder() async {
    final payload = widget.payload;
    if (payload == null) return;

    final user = AppSupabase.client.auth.currentUser;
    if (user == null) return;

    setState(() => _placing = true);

    try {
      final orderJson = payload.toOrderJson(user.id);
      await AppSupabase.client.from('orders').insert(orderJson);

      // If the customer asked for a home tailor visit, dispatch a row
      // to `tailor_appointments` so the Partner app's realtime radar
      // lights up on every online tailor's phone within a second.
      // Wrapped in its own try so an appointment hiccup never strands
      // a paid order — the order is the source of truth and is already
      // committed by the time we get here. Worst-case dispatch failure
      // is fixable by ops via a re-trigger or a manual INSERT.
      //
      // We also capture the returned appointment id and thread it to
      // the success screen as a query param so the customer can deep-
      // link straight into the live `tailor-visit/<id>` tracker — this
      // is what closes the loop with the Partner app's status updates.
      // Without it, the success screen has no way to know an
      // appointment exists and the customer never sees the Realtime
      // progression as it happens.
      String? tailorVisitId;
      if (payload.measurementMethod == 'tailor' &&
          payload.tailorScheduledTime != null &&
          (payload.tailorAddress?.isNotEmpty ?? false)) {
        try {
          // Marketplace flow: the customer picked a specific tailor
          // on /measurements/select-tailor, so payload.tailorId is
          // set and the appointment row lands directly in that
          // tailor's inbox (migration 036's RLS scope) with status
          // 'pending_tailor_approval'.
          // Legacy flow: payload.tailorId is null → row lands as
          // 'pending' broadcast to every online tailor.
          tailorVisitId = await TailorAppointmentService().requestVisit(
            address: _composeAppointmentAddress(payload),
            scheduledTime: payload.tailorScheduledTime!,
            tailorId: payload.tailorId,
          );
        } catch (e, st) {
          debugPrint('Cart: tailor dispatch failed (non-fatal) — $e\n$st');
        }
      }

      if (!mounted) return;
      // Build a single Uri so go_router parses the query param correctly
      // even when [tailorVisitId] is null (in which case we just route
      // to a clean `/order-success`).
      final successUri = Uri(
        path: '/order-success',
        queryParameters: tailorVisitId == null
            ? null
            : {'tailorVisitId': tailorVisitId},
      );
      context.go(successUri.toString());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: $e')),
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  /// Combine the payload's address + pincode into the single string the
  /// `tailor_appointments.address` column expects. Pincode is appended
  /// when present so the partner can geocode without a second lookup.
  String _composeAppointmentAddress(OrderPayload payload) {
    final addr = payload.tailorAddress?.trim() ?? '';
    final pin = payload.tailorPincode?.trim() ?? '';
    if (pin.isEmpty) return addr;
    return '$addr — $pin';
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.payload;

    if (payload == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No items in cart')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Review Order',
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
            // ── Product Card ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withAlpha(60)),
              ),
              child: Row(
                children: [
                  // Image placeholder
                  Container(
                    width: 80,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      image: payload.imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(payload.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: payload.imageUrl == null
                        ? const Icon(Icons.checkroom_rounded,
                            color: AppColors.textTertiary)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (payload.isRecreatedLook) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withAlpha(22),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.accent.withAlpha(80),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome,
                                    size: 11, color: AppColors.accent),
                                const SizedBox(width: 4),
                                Text(
                                  'AI RECREATED',
                                  style: GoogleFonts.manrope(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          payload.productName,
                          style: GoogleFonts.newsreader(
                            fontSize: 20,
                            fontStyle: FontStyle.italic,
                            color: AppColors.primary,
                          ),
                        ),
                        if (payload.fabric != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            payload.fabric!,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          Money.formatStatic(payload.price),
                          style: GoogleFonts.manrope(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Measurement Method ──
            _sectionLabel('MEASUREMENT METHOD'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border.withAlpha(60)),
              ),
              child: payload.measurementMethod == 'tailor'
                  ? _tailorDetails(payload)
                  : _manualDetails(payload),
            ),

            const SizedBox(height: 24),

            // ── Price Breakdown ──
            _sectionLabel('PRICE BREAKDOWN'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border.withAlpha(60)),
              ),
              child: Column(
                children: [
                  _priceRow('Product', Money.formatStatic(payload.price)),
                  const SizedBox(height: 10),
                  _priceRow('Stitching', 'Included'),
                  const SizedBox(height: 10),
                  _priceRow(
                    'Home Tailor Visit',
                    payload.measurementMethod == 'tailor' ? 'FREE' : '—',
                  ),
                  const SizedBox(height: 10),
                  _priceRow('Delivery', 'FREE'),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        Money.formatStatic(payload.price),
                        style: GoogleFonts.manrope(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Delivery Estimate ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withAlpha(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Estimated delivery in 10–14 working days after approval.',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: AppColors.primary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _placing ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border.withAlpha(80),
                elevation: 8,
                shadowColor: AppColors.primary.withAlpha(60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _placing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'PLACE ORDER  •  ${Money.formatStatic(payload.price)}',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _manualDetails(OrderPayload payload) {
    final measurements = payload.measurements ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_note_rounded,
                  size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Text(
              'Manual Measurements',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        if (measurements.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: measurements.entries.map((e) {
              final label = e.key.replaceAll('_', ' ');
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${label[0].toUpperCase()}${label.substring(1)}: ${e.value}"',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _tailorDetails(OrderPayload payload) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_pin_circle_rounded,
                  size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Home Tailor Visit',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'FREE',
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (payload.tailorAddress != null)
          _infoRow(Icons.location_on_outlined, payload.tailorAddress!),
        if (payload.tailorDate != null)
          _infoRow(Icons.calendar_today_rounded, payload.tailorDate!),
        if (payload.tailorTimeSlot != null)
          _infoRow(Icons.schedule_rounded, payload.tailorTimeSlot!),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: AppColors.textTertiary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
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
}
