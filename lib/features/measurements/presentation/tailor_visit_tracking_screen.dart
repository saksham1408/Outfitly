import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../data/tailor_appointment_service.dart';
import '../data/tailor_review_service.dart';
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
  final _reviewService = TailorReviewService();

  /// True once we've checked the DB and confirmed the customer has
  /// already left a review for this appointment. Suppresses the
  /// "Rate your tailor" CTA on subsequent visits to the screen so
  /// the surface stays clean.
  bool _alreadyReviewed = false;
  bool _reviewLookupDone = false;

  Future<void> _checkExistingReview() async {
    if (_reviewLookupDone) return;
    final existing =
        await _reviewService.fetchByAppointment(widget.appointmentId);
    if (!mounted) return;
    setState(() {
      _alreadyReviewed = existing != null;
      _reviewLookupDone = true;
    });
  }

  Future<void> _openReviewScreen() async {
    final submitted = await context
        .push<bool>('/tailor-review/${widget.appointmentId}');
    if (submitted == true && mounted) {
      setState(() => _alreadyReviewed = true);
    }
  }

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

          // Lazy-fetch the existing review once the visit hits the
          // completed state — until then there's nothing to check
          // for, and we'd just be running a dead query on every
          // stream emission.
          if (visit.isCompleted && !_reviewLookupDone) {
            _checkExistingReview();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusHero(visit: visit),

                // ── "Rate your tailor" CTA ──
                // Only renders when the visit is completed AND the
                // customer hasn't already submitted a review (we
                // re-check on the way back from the review screen
                // so the card disappears immediately after a
                // successful submit). The CTA isn't a passive
                // notice — it's an active gold pill so the request
                // for feedback feels celebratory rather than
                // chore-like.
                if (visit.isCompleted && !_alreadyReviewed) ...[
                  const SizedBox(height: 16),
                  _RateTailorCta(
                    tailorName: visit.tailor?.fullName ?? 'your tailor',
                    onTap: _openReviewScreen,
                  ),
                ],

                const SizedBox(height: 24),
                _sectionLabel('YOUR TAILOR'),
                const SizedBox(height: 12),
                _TailorCard(visit: visit),
                // The timeline only earns real estate once a tailor
                // has actually picked up the request — until then
                // the "Finding a tailor" tailor card carries the
                // whole waiting-state story on its own.
                if (!visit.isPending && !visit.isCancelled) ...[
                  const SizedBox(height: 28),
                  _sectionLabel('PROGRESS'),
                  const SizedBox(height: 12),
                  _ProgressTimeline(visit: visit),
                ],
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
    final name = visit.tailor?.fullName ?? 'Your tailor';
    switch (visit.status) {
      case TailorVisitStatus.pending:
        return (
          'Finding a tailor near you…',
          'We\'re pinging every Partner in your area. You\'ll see their '
              'name here the moment someone picks up.',
        );
      case TailorVisitStatus.pendingTailorApproval:
        return (
          'Waiting on $name to confirm…',
          'You picked them from the marketplace — they\'ll get a ping '
              'and have a few minutes to accept or pass. Status updates '
              'land here automatically.',
        );
      case TailorVisitStatus.accepted:
        return (
          '$name has accepted.',
          'They\'re wrapping up at the workshop. We\'ll update this screen '
              'the moment they head out.',
        );
      case TailorVisitStatus.enRoute:
        return (
          '$name is on the way.',
          'Sit tight — they\'ll knock when they\'re at your door.',
        );
      case TailorVisitStatus.arrived:
        return (
          '$name is at your door.',
          'Let them in whenever you\'re ready. Measurements take about '
              '15 minutes.',
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
// Progress Timeline
// ────────────────────────────────────────────────────────────
/// Vertical four-step timeline that renders the customer-facing
/// view of the Partner app's stepper. Reads
/// [TailorVisitStatus.progressIndex] (pending=0, accepted=1,
/// enRoute=2, arrived=3, completed=4) and fills every step whose
/// progress index is ≤ the current one.
///
/// Only rendered once the visit has moved past `pending` — the
/// "Finding a tailor" tailor card carries the whole waiting-state
/// story on its own.
class _ProgressTimeline extends StatelessWidget {
  const _ProgressTimeline({required this.visit});

  final TailorVisit visit;

  // Step 0 (pending) is the pre-history — the timeline begins the
  // moment a tailor accepts. Indices here map 1:1 onto the filled
  // states a claimed row walks through.
  static const _steps = <_TimelineStep>[
    _TimelineStep(
      status: TailorVisitStatus.accepted,
      title: 'Request accepted',
      sub: 'A tailor has picked up your visit.',
      icon: Icons.check,
    ),
    _TimelineStep(
      status: TailorVisitStatus.enRoute,
      title: 'On the way',
      sub: 'Heading over with the measuring kit.',
      icon: Icons.directions_car,
    ),
    _TimelineStep(
      status: TailorVisitStatus.arrived,
      title: 'At your door',
      sub: 'Ready whenever you are.',
      icon: Icons.location_on,
    ),
    _TimelineStep(
      status: TailorVisitStatus.completed,
      title: 'Measurements complete',
      sub: 'Saved to your profile.',
      icon: Icons.done_all,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final current = visit.status.progressIndex;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(_steps.length, (i) {
          final step = _steps[i];
          final stepIndex = step.status.progressIndex;
          final reached = stepIndex <= current;
          final isCurrent = stepIndex == current;
          final isLast = i == _steps.length - 1;
          return _TimelineRow(
            step: step,
            reached: reached,
            isCurrent: isCurrent,
            isLast: isLast,
          );
        }),
      ),
    );
  }
}

class _TimelineStep {
  const _TimelineStep({
    required this.status,
    required this.title,
    required this.sub,
    required this.icon,
  });

  final TailorVisitStatus status;
  final String title;
  final String sub;
  final IconData icon;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.reached,
    required this.isCurrent,
    required this.isLast,
  });

  final _TimelineStep step;
  final bool reached;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final accent = reached ? AppColors.accent : AppColors.border;
    final iconColor = reached ? Colors.white : AppColors.textTertiary;
    final titleColor = reached
        ? AppColors.textPrimary
        : AppColors.textTertiary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gutter: node + vertical connector.
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: reached ? AppColors.accent : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent,
                      width: isCurrent ? 2.5 : 1.5,
                    ),
                  ),
                  child: Icon(step.icon, size: 15, color: iconColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: reached
                          ? AppColors.accent
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Label column. Bottom padding on every row except the
          // last so the stack has breathing room.
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: isCurrent
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.sub,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: reached
                          ? AppColors.textSecondary
                          : AppColors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

/// "Rate your tailor" CTA — only rendered when the visit has
/// completed and no review exists yet. Gold-tinted card with stars
/// + a chevron so it reads as an action, not a passive update.
class _RateTailorCta extends StatelessWidget {
  const _RateTailorCta({required this.tailorName, required this.onTap});

  final String tailorName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accent.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withAlpha(60)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.star_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate $tailorName',
                      style: GoogleFonts.manrope(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your review helps other customers + rewards great work',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.accent.withAlpha(180),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
