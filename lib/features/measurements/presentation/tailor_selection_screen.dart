import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../../checkout/models/order_payload.dart';
import '../data/tailor_repository.dart';
import '../domain/tailor_visit.dart';

/// User-Selected Tailor Marketplace.
///
/// Inserted between the booking form (`BookTailorScreen`) and the
/// cart review (`CartScreen`). The customer browses a list of
/// rated tailor profiles, taps "Select This Tailor" on the one
/// they want, and the chosen tailor's id + name get pinned to the
/// [OrderPayload] before we push to /cart for the final review
/// + place-order beat.
///
/// Design beats (per spec):
///   * Header: "Select Your Master Tailor" + subtitle.
///   * Premium vertical list of cards.
///   * Each card: avatar, name + verification badge, rating +
///     jobs completed, specialty chips, "Select This Tailor" CTA.
///
/// We don't show a city/pincode-aware empty state yet — for the
/// MVP the repository ignores location and returns every tailor.
/// The spinner / empty / error branches still exist for the case
/// where the table is empty or the network failed.
class TailorSelectionScreen extends StatefulWidget {
  const TailorSelectionScreen({super.key, required this.payload});

  final OrderPayload payload;

  @override
  State<TailorSelectionScreen> createState() =>
      _TailorSelectionScreenState();
}

class _TailorSelectionScreenState extends State<TailorSelectionScreen> {
  final _repo = TailorRepository();

  List<TailorProfile> _tailors = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tailors = await _repo.fetchNearbyTailors(
      location: widget.payload.tailorPincode,
    );
    if (!mounted) return;
    setState(() {
      _tailors = tailors;
      _loading = false;
    });
  }

  void _select(TailorProfile tailor) {
    // Pin the chosen tailor onto the payload — the cart's
    // `_placeOrder` will read it, and TailorAppointmentService
    // bakes it into the appointment row so only this tailor sees
    // the request.
    widget.payload.tailorId = tailor.id;
    widget.payload.tailorName = tailor.fullName;
    context.push('/cart', extra: widget.payload);
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
          'Choose a tailor',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _Header(pincode: widget.payload.tailorPincode),
                  const SizedBox(height: 20),
                  if (_tailors.isEmpty)
                    const _EmptyState()
                  else
                    for (final t in _tailors) ...[
                      _TailorCard(tailor: t, onSelect: () => _select(t)),
                      const SizedBox(height: 14),
                    ],
                ],
              ),
      ),
    );
  }
}

/// Top-of-page hero — the spec-required headline + subtitle.
class _Header extends StatelessWidget {
  final String? pincode;

  const _Header({this.pincode});

  @override
  Widget build(BuildContext context) {
    final hasPin = pincode != null && pincode!.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Your Master Tailor',
          style: GoogleFonts.newsreader(
            fontSize: 28,
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
          hasPin
              ? 'Top-rated professionals near $pincode'
              : 'Top-rated professionals near your location',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// One tailor card — the meat of the screen.
class _TailorCard extends StatelessWidget {
  final TailorProfile tailor;
  final VoidCallback onSelect;

  const _TailorCard({required this.tailor, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withAlpha(15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Identity row: avatar + name + verification ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(tailor: tailor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tailor.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.newsreader(
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (tailor.isVerified) ...[
                          const SizedBox(width: 6),
                          // Filled verified-style badge — small blue
                          // check on a tinted circle. Not the OS
                          // checkmark since the brand is purple/gold;
                          // stick with primary tone.
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tailor.experienceYears} '
                      '${tailor.experienceYears == 1 ? "year" : "years"} '
                      'experience',
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
          const SizedBox(height: 14),

          // ── Rating + jobs row ──
          Row(
            children: [
              _Stat(
                icon: Icons.star_rounded,
                iconColor: AppColors.accent,
                label: tailor.rating > 0
                    ? tailor.rating.toStringAsFixed(1)
                    : 'New',
                sublabel: tailor.rating > 0 ? 'Rating' : 'No reviews',
              ),
              const SizedBox(width: 18),
              _Stat(
                icon: Icons.handyman_rounded,
                iconColor: AppColors.primary,
                label: '${tailor.totalReviews}',
                sublabel:
                    tailor.totalReviews == 1 ? 'Job done' : 'Jobs done',
              ),
            ],
          ),

          // ── Specialty chips ──
          if (tailor.specialties.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in tailor.specialties) _SpecialtyChip(label: s),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // ── Select CTA ──
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'SELECT THIS TAILOR',
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
    );
  }
}

/// Initial-letter avatar circle — same fallback pattern as the Loop
/// dashboard's [FriendProfile] avatar. tailor_profiles doesn't carry
/// an avatar_url today; when it does, drop in a NetworkImage on the
/// `image` field of the BoxDecoration.
class _Avatar extends StatelessWidget {
  final TailorProfile tailor;

  const _Avatar({required this.tailor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withAlpha(15),
        border: Border.all(
          color: AppColors.primary.withAlpha(40),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        tailor.initial,
        style: GoogleFonts.newsreader(
          fontSize: 26,
          fontStyle: FontStyle.italic,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// Single rating / jobs stat block — icon + bold value over a
/// secondary label. Used on the row directly below the tailor's
/// name so the credibility numbers read at a glance.
class _Stat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;

  const _Stat({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                height: 1.0,
              ),
            ),
            Text(
              sublabel,
              style: GoogleFonts.manrope(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Small specialty pill — primary-tinted background, primary text,
/// rounded corners. Renders 'Suits', 'Sherwanis', 'Bridal' etc. as
/// the tailor's self-tagged areas of focus.
class _SpecialtyChip extends StatelessWidget {
  final String label;

  const _SpecialtyChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withAlpha(30)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Empty state — table is empty, network failed, or no tailors
/// match the user's location yet. Keeps the customer from staring
/// at a blank list.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(15)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.checkroom_outlined,
            size: 56,
            color: AppColors.primary.withAlpha(80),
          ),
          const SizedBox(height: 14),
          Text(
            'No tailors available right now',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pull down to refresh — new partners join the platform every week.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
