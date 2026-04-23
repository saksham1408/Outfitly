import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../data/tailor_appointment_service.dart';
import '../domain/tailor_visit.dart';

/// Live tracker for a single home-tailor-visit request.
///
/// The customer lands here immediately after tapping "REQUEST TAILOR
/// VISIT" on [BookTailorScreen]. Rendered over a Supabase Realtime
/// stream, so the page transitions itself the moment a Partner on the
/// other side of the wire flips the row to `accepted`.
///
/// Three zones stacked top-to-bottom:
///   1. Status hero — big dark card with a pill + the human-readable
///      status line ("Finding a tailor near you…" / "Dispatched!").
///   2. YOUR TAILOR — placeholder with a pulsing dot while pending;
///      swaps to a filled card with the tailor's name + experience
///      the instant the acceptance lands.
///   3. Visit details — scheduled time + address, rendered as a
///      label/value list that mirrors the product-order tracking
///      screen so both flows feel like the same product.
class TailorVisitTrackingScreen extends StatefulWidget {
  const TailorVisitTrackingScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  State<TailorVisitTrackingScreen> createState() =>
      _TailorVisitTrackingScreenState();
}

class _TailorVisitTrackingScreenState extends State<TailorVisitTrackingScreen> {
  final _service = TailorAppointmentService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Home Tailor Visit',
          style: GoogleFonts.newsreader(
            fontSize: 22,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
          ),
        ),
      ),
      body: StreamBuilder<TailorVisit>(
        stream: _service.watchVisit(widget.appointmentId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final visit = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusHero(visit: visit),
                const SizedBox(height: 24),
                _sectionLabel('YOUR TAILOR'),
                const SizedBox(height: 12),
                _TailorCard(visit: visit),
                const SizedBox(height: 28),
                _sectionLabel('VISIT DETAILS'),
                const SizedBox(height: 12),
                _DetailsCard(visit: visit),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
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
}

// ────────────────────────────────────────────────────────────
// Status Hero
// ────────────────────────────────────────────────────────────
class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.visit});

  final TailorVisit visit;

  @override
  Widget build(BuildContext context) {
    final (headline, sub) = _copy(visit);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accentContainer.withAlpha(60),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              visit.status.label.toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: AppColors.accentContainer,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            headline,
            style: GoogleFonts.newsreader(
              fontSize: 24,
              fontStyle: FontStyle.italic,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: Colors.white.withAlpha(180),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Two-line copy that narrates the current phase — kept small so
  /// the card reads at a glance and the emotional beat matches what
  /// the customer is actually waiting on.
  (String, String) _copy(TailorVisit visit) {
    switch (visit.status) {
      case TailorVisitStatus.pending:
        return (
          'Finding a tailor near you…',
          'We\'re pinging every Partner in your area. You\'ll see their '
              'name here the moment someone picks up.',
        );
      case TailorVisitStatus.accepted:
        final name = visit.tailor?.fullName ?? 'Your tailor';
        return (
          '$name is on the way.',
          'We\'ll keep this screen live until they arrive and finish taking '
              'your measurements.',
        );
      case TailorVisitStatus.completed:
        return (
          'Measurements complete.',
          'Your measurements are saved to your profile. You can place a '
              'custom order any time.',
        );
      case TailorVisitStatus.cancelled:
        return (
          'This visit was cancelled.',
          'Open the Home screen to book another time.',
        );
    }
  }
}

// ────────────────────────────────────────────────────────────
// Tailor Card
// ────────────────────────────────────────────────────────────
class _TailorCard extends StatelessWidget {
  const _TailorCard({required this.visit});

  final TailorVisit visit;

  @override
  Widget build(BuildContext context) {
    final tailor = visit.tailor;

    // Pending / unassigned → empty state with a searching beacon.
    if (tailor == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withAlpha(20),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.search,
                color: AppColors.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Awaiting a tailor',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'We\'ll notify you the moment one accepts.',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Assigned → filled card with name + experience.
    final initial = tailor.fullName.trim().isEmpty
        ? '?'
        : tailor.fullName.trim()[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withAlpha(18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: GoogleFonts.newsreader(
                fontSize: 24,
                fontStyle: FontStyle.italic,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tailor.fullName,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _experienceLabel(tailor.experienceYears),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(20),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, size: 14, color: AppColors.accent),
                const SizedBox(width: 4),
                Text(
                  'Partner',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _experienceLabel(int years) {
    if (years <= 0) return 'New on Outfitly';
    if (years == 1) return '1 year of experience';
    return '$years years of experience';
  }
}

// ────────────────────────────────────────────────────────────
// Details Card (scheduled time + address)
// ────────────────────────────────────────────────────────────
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.visit});

  final TailorVisit visit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _row('Scheduled', _formatScheduled(visit.scheduledTime)),
          const Divider(height: 20),
          _row('Address', visit.address, multiline: true),
          const Divider(height: 20),
          _row(
            'Booked',
            _formatDate(visit.createdAt),
          ),
          const Divider(height: 20),
          _row(
            'Request ID',
            visit.id.substring(0, 8).toUpperCase(),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool multiline = false}) {
    return Row(
      crossAxisAlignment:
          multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String _formatScheduled(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour == 0
        ? 12
        : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} · $hour:$min $ampm';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ────────────────────────────────────────────────────────────
// Error state
// ────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'Could not load this visit.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
