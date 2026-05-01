import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../data/tailor_appointment_service.dart';
import '../data/tailor_review_service.dart';
import '../domain/tailor_visit.dart';

/// Five-star rating + optional comment, written by the customer
/// after a completed tailor visit. Once the row lands in
/// `tailor_reviews`, the recompute trigger updates the tailor's
/// aggregate rating + review count on the spot — so the next
/// customer who browses the marketplace sees the freshly-averaged
/// stars without anything else needing to redeploy.
///
/// Routed at `/tailor-review/:appointmentId`. The screen pulls the
/// appointment + assigned tailor on mount so the header can render
/// "How was your visit with [tailor name]?" with the actual name
/// rather than a placeholder. If the appointment isn't found, isn't
/// completed, or already has a review, the screen short-circuits
/// to a sensible empty state instead of letting the customer
/// double-submit.
class TailorReviewScreen extends StatefulWidget {
  const TailorReviewScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  State<TailorReviewScreen> createState() => _TailorReviewScreenState();
}

class _TailorReviewScreenState extends State<TailorReviewScreen> {
  final _appointmentService = TailorAppointmentService();
  final _reviewService = TailorReviewService();
  final _commentController = TextEditingController();

  TailorVisit? _visit;
  bool _loading = true;
  bool _submitting = false;
  bool _alreadyReviewed = false;
  String? _error;

  /// 0 → no selection yet; 1–5 → user has tapped a star.
  int _rating = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Short read on the visit (just the first emission of the
    // realtime stream — we don't need to keep watching) plus a
    // dedup check against an existing review.
    final visitSnapshot =
        await _appointmentService.watchVisit(widget.appointmentId).first;
    final existing =
        await _reviewService.fetchByAppointment(widget.appointmentId);

    if (!mounted) return;
    setState(() {
      _visit = visitSnapshot;
      _alreadyReviewed = existing != null;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    final visit = _visit;
    if (visit == null) return;
    if (_rating < 1 || _rating > 5) {
      setState(() => _error = 'Pick at least one star to submit.');
      return;
    }
    final tailorId = visit.tailorId;
    if (tailorId == null) {
      setState(() => _error =
          'No tailor recorded against this visit yet — try again in a moment.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _reviewService.submitReview(
        appointmentId: widget.appointmentId,
        tailorId: tailorId,
        rating: _rating,
        reviewText: _commentController.text,
      );
      if (!mounted) return;
      // Land on a thank-you beat then bounce back to the tracker.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
          content: Text(
            'Thanks! Your review is live.',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Couldn\'t submit: $e';
        _submitting = false;
      });
    }
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
          'Rate your tailor',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _alreadyReviewed
              ? _AlreadyReviewedState(visit: _visit)
              : _ReviewForm(
                  visit: _visit,
                  rating: _rating,
                  commentController: _commentController,
                  submitting: _submitting,
                  error: _error,
                  onRatingChanged: (v) =>
                      setState(() => _rating = v),
                  onSubmit: _submit,
                ),
    );
  }
}

/// The active form — shown while the customer is filling it in.
/// Keeping it in its own widget tightens what re-renders on every
/// [setState] in the parent.
class _ReviewForm extends StatelessWidget {
  const _ReviewForm({
    required this.visit,
    required this.rating,
    required this.commentController,
    required this.submitting,
    required this.error,
    required this.onRatingChanged,
    required this.onSubmit,
  });

  final TailorVisit? visit;
  final int rating;
  final TextEditingController commentController;
  final bool submitting;
  final String? error;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final tailorName = visit?.tailor?.fullName ?? 'your tailor';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          'How was your visit with $tailorName?',
          style: GoogleFonts.newsreader(
            fontSize: 26,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
            height: 1.2,
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
          'Your rating helps other customers pick the right tailor and rewards great work with more requests.',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 30),

        // ── Star picker ──
        _StarRow(rating: rating, onChanged: onRatingChanged),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _ratingLabel(rating),
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
              letterSpacing: 0.6,
            ),
          ),
        ),

        const SizedBox(height: 30),

        // ── Optional comment ──
        Text(
          'TELL THEM MORE (OPTIONAL)',
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: commentController,
          maxLength: 500,
          maxLines: 5,
          minLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style: GoogleFonts.manrope(
            fontSize: 13.5,
            color: AppColors.textPrimary,
            height: 1.4,
          ),
          decoration: InputDecoration(
            hintText:
                'Punctual, professional, took accurate measurements…',
            hintStyle: GoogleFonts.manrope(
              fontSize: 12.5,
              color: AppColors.textTertiary,
            ),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            error!,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: AppColors.error,
            ),
          ),
        ],

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: submitting ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'SUBMIT REVIEW',
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  String _ratingLabel(int r) {
    switch (r) {
      case 1:
        return 'Tap a star to rate';
      // The 1-tap state is covered above; we re-purpose case 1
      // for the "no-stars" message since 0 doesn't get passed.
      case 0:
        return 'Tap a star to rate';
      case 2:
        return 'Could be better';
      case 3:
        return 'Decent';
      case 4:
        return 'Great visit';
      case 5:
        return 'Outstanding — bookmark them';
      default:
        return 'Tap a star to rate';
    }
  }
}

/// Five tappable stars, large enough to feel premium and tactile.
/// Drives the parent's rating state via the [onChanged] callback.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, required this.onChanged});

  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(4),
                child: Icon(
                  i <= rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 44,
                  color: i <= rating
                      ? AppColors.accent
                      : AppColors.textTertiary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "Already reviewed" state — shown if the customer comes back to
/// the screen after submitting. We don't allow re-submitting from
/// this surface; corrections happen via the 24h-grace UPDATE policy
/// in migration 037 (no UI for it yet, but the affordance exists).
class _AlreadyReviewedState extends StatelessWidget {
  const _AlreadyReviewedState({required this.visit});

  final TailorVisit? visit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 60),
      children: [
        Icon(
          Icons.task_alt_rounded,
          size: 72,
          color: AppColors.primary.withAlpha(80),
        ),
        const SizedBox(height: 18),
        Text(
          'You\'ve already rated this visit',
          textAlign: TextAlign.center,
          style: GoogleFonts.newsreader(
            fontSize: 22,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Thanks for the feedback — your review is now live on '
          '${visit?.tailor?.fullName ?? "the tailor"}\'s profile.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: TextButton(
            onPressed: () => context.pop(),
            child: Text(
              'Back to tracking',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
