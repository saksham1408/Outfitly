import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../data/promotions_repository.dart';
import '../models/promo_offer.dart';

/// "Active Offers & Sales" dashboard.
///
/// The push notification fan-out from a new sale launch deep-links
/// here (FCM data: `{ route: '/offers' }`). The screen is also
/// reachable manually from the Home AppBar's percent-tag icon, so
/// users who never tapped the notification can still find it.
///
/// Design beats:
///   * Dark gradient banner cards — high-contrast against the warm
///     beige app background, premium "limited-time" tone.
///   * Massive typography for the discount ("GET 20% OFF").
///   * Subtle countdown timer ticking under each card.
///   * Tap routes to the offer's `target_route` (catalog filter,
///     subcategory deep-link, etc.) so the user can act on the
///     deal in one tap.
class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final _repo = PromotionsRepository();

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
          'Current Offers & Deals',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<List<PromoOffer>>(
        // Realtime stream so a freshly-published offer flips onto
        // the dashboard the moment marketing toggles `is_active`,
        // even if the user is already on the screen.
        stream: _repo.watchActive(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final offers = snapshot.data ?? const [];
          if (offers.isEmpty) return const _EmptyState();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: offers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) =>
                _OfferCard(offer: offers[i]),
          );
        },
      ),
    );
  }
}

/// One offer card — dark gradient, hero discount, countdown, CTA.
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});

  final PromoOffer offer;

  void _onTap(BuildContext context) {
    final route = offer.targetRoute;
    // Defensive: if the offer points back at /offers (the screen
    // we're already on) OR has no route at all, bounce to /catalog
    // so the tap always goes somewhere different. Without this,
    // a marketing row with target_route='/offers' would push the
    // same screen on top of itself — the user sees no visible
    // change and assumes the tap is broken.
    final isUseful = route != null &&
        route.isNotEmpty &&
        route != '/offers';
    context.push(isUseful ? route : '/catalog');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTap(context),
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              // Gradient base — `primary` (deep purple) at top
              // deepening to near-black at the bottom. Reads as
              // "premium limited-time event" against the warm
              // beige background.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withAlpha(220),
                  Colors.black.withAlpha(220),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Banner image overlay — fills the card, alpha-
                // blended so the gradient remains the dominant
                // backdrop and the typography stays readable.
                if (offer.bannerImageUrl != null)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.32,
                      child: Image.network(
                        offer.bannerImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),
                // Top-right tag — "ACTIVE" pill so the card reads
                // as live the moment it pops onto the screen.
                Positioned(
                  top: 14,
                  right: 14,
                  child: _ActivePill(),
                ),
                // Card content.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.title.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: AppColors.accentContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Hero discount — the visual centrepiece.
                      // Massive italic newsreader at 56pt so the
                      // "20% OFF" reads from across the room.
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'GET ',
                              style: GoogleFonts.newsreader(
                                fontSize: 30,
                                fontStyle: FontStyle.italic,
                                color: Colors.white,
                              ),
                            ),
                            TextSpan(
                              text: '${offer.discountPercentage}%',
                              style: GoogleFonts.newsreader(
                                fontSize: 56,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                                height: 1.0,
                              ),
                            ),
                            TextSpan(
                              text: ' OFF',
                              style: GoogleFonts.newsreader(
                                fontSize: 30,
                                fontStyle: FontStyle.italic,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (offer.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          offer.description!,
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            color: Colors.white.withAlpha(200),
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Countdown + promo code row — countdown is
                      // the urgency hook; promo code (if any) is
                      // the "you'll need this at checkout" beat.
                      Row(
                        children: [
                          _CountdownBadge(endDate: offer.endDate),
                          const SizedBox(width: 10),
                          if (offer.promoCode != null)
                            _PromoCodeBadge(code: offer.promoCode!),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'SHOP NOW',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Self-updating countdown badge. Re-renders once per second so
/// the timer actually ticks — at the cost of a 1-second timer
/// per card, which is fine at the cardinality we expect (handful
/// of live offers at any moment).
class _CountdownBadge extends StatefulWidget {
  const _CountdownBadge({required this.endDate});

  final DateTime endDate;

  @override
  State<_CountdownBadge> createState() => _CountdownBadgeState();
}

class _CountdownBadgeState extends State<_CountdownBadge> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    if (d.inSeconds <= 0) return 'EXPIRED';
    if (d.inDays > 0) {
      return '${d.inDays}d ${d.inHours.remainder(24)}h left';
    }
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m left';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s left';
    }
    return '${d.inSeconds}s left';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.endDate.difference(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 12,
            color: Colors.white.withAlpha(220),
          ),
          const SizedBox(width: 4),
          Text(
            _format(remaining),
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(230),
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "USE CODE: XYZ" pill that sits next to the countdown
/// when the offer carries a promo code. Tappable in a future
/// iteration so a user can copy-to-clipboard; for now it's a
/// purely visual hint that they'll need the code at checkout.
class _PromoCodeBadge extends StatelessWidget {
  const _PromoCodeBadge({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(40),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accent.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.tag_rounded,
              size: 11, color: AppColors.accentContainer),
          const SizedBox(width: 4),
          Text(
            code,
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.accentContainer,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny pulsing-dot pill in the top-right corner of every active
/// offer card — anchors the "this is live right now" framing.
class _ActivePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(40),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.greenAccent.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'ACTIVE',
            style: GoogleFonts.manrope(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.greenAccent,
            ),
          ),
        ],
      ),
    );
  }
}

/// "No offers" state — when no live promotions exist we don't
/// want the screen to feel broken. A friendly empty state with
/// a "we'll let you know" beat keeps the customer reassured
/// they're on the right surface.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 80, 40, 40),
      child: Column(
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 72,
            color: AppColors.primary.withAlpha(80),
          ),
          const SizedBox(height: 18),
          Text(
            'No live offers right now',
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              fontSize: 22,
              fontStyle: FontStyle.italic,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll send you a notification the moment our next sale goes live. In the meantime, browse the catalog to bookmark pieces you love.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
