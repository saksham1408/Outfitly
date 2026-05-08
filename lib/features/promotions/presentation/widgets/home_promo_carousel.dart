import 'dart:async';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/theme/theme.dart';
import '../../data/promotions_repository.dart';
import '../../models/promo_offer.dart';

/// Premium auto-sliding promo carousel anchored at the top of
/// the Home screen. Mirrors the Myntra hero slot in *behaviour*
/// (auto-rotate, pagination dots, peek-the-next-slide) but with
/// two distinct in-house slide designs:
///
///   • [_FlashSaleSlide]  — image-backed sale slide with a live
///                           countdown + "Shop Now" pill.
///   • [_BankOfferSlide]  — metallic credit-card-style slide
///                           with a Copy Code button and a
///                           subtle bank-chip watermark.
///
/// Data source: live `promo_offers` rows via
/// [PromotionsRepository.watchActive] — same stream the
/// `/offers` dashboard uses, so a row published by the marketing
/// team appears here within a second of `is_active` flipping
/// true. The carousel hides itself entirely when the live
/// offer set is empty so it never reserves dead space on the
/// home screen.
class HomePromoCarousel extends StatefulWidget {
  const HomePromoCarousel({super.key});

  @override
  State<HomePromoCarousel> createState() => _HomePromoCarouselState();
}

class _HomePromoCarouselState extends State<HomePromoCarousel> {
  final _repo = PromotionsRepository();
  final _carouselController = CarouselSliderController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PromoOffer>>(
      stream: _repo.watchActive(),
      builder: (context, snapshot) {
        final offers = snapshot.data ?? const <PromoOffer>[];

        // Empty state — collapse to zero height so the rest of
        // the home feed slides up. Sidesteps the "ugly hardcoded
        // skeleton block on cold launch" antipattern.
        if (offers.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Column(
            children: [
              CarouselSlider.builder(
                carouselController: _carouselController,
                itemCount: offers.length,
                options: CarouselOptions(
                  // Tall enough for headline + body + CTA without
                  // forcing the home feed to scroll a half-screen
                  // before the first product card is visible.
                  height: 184,
                  // Premium "popping centre card" effect — side
                  // slides shrink ~10% so the focal slide sits
                  // forward.
                  enlargeCenterPage: true,
                  enlargeFactor: 0.18,
                  // Peek the next slide so the user knows there's
                  // more content waiting — Myntra's signature.
                  viewportFraction: 0.9,
                  // Auto-rotate, pause on touch so a user
                  // reading copy doesn't lose their slide.
                  autoPlay: true,
                  autoPlayInterval: const Duration(seconds: 5),
                  autoPlayAnimationDuration:
                      const Duration(milliseconds: 700),
                  autoPlayCurve: Curves.easeOutCubic,
                  pauseAutoPlayOnTouch: true,
                  // Single-slide cases get auto-play turned off
                  // by carousel_slider internally; the dot row
                  // also collapses to a single dot.
                  enableInfiniteScroll: offers.length > 1,
                  onPageChanged: (i, _) =>
                      setState(() => _currentPage = i),
                ),
                itemBuilder: (context, index, _) {
                  final offer = offers[index];
                  switch (offer.offerType) {
                    case OfferType.bankOffer:
                      return _BankOfferSlide(offer: offer);
                    case OfferType.sale:
                      return _FlashSaleSlide(offer: offer);
                  }
                },
              ),
              if (offers.length > 1) ...[
                const SizedBox(height: 12),
                AnimatedSmoothIndicator(
                  activeIndex: _currentPage,
                  count: offers.length,
                  effect: ExpandingDotsEffect(
                    activeDotColor: AppColors.primary,
                    dotColor: AppColors.primary.withAlpha(45),
                    dotWidth: 7,
                    dotHeight: 7,
                    expansionFactor: 3.6,
                    spacing: 6,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────
// Design A — Flash Sale slide
// ────────────────────────────────────────────────────────────

/// Image-backed sale slide. Renders the offer's banner photo
/// with a dark gradient overlay so the bold sans headline reads
/// even on a busy background, plus a live countdown badge that
/// updates every second.
class _FlashSaleSlide extends StatelessWidget {
  const _FlashSaleSlide({required this.offer});

  final PromoOffer offer;

  void _onTap(BuildContext context) {
    final route = offer.targetRoute;
    if (route == null || route.isEmpty) return;
    // The /offers screen guards against self-loops; rest of
    // the targets are the merch team's responsibility.
    context.push(route == '/offers' ? '/catalog' : route);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTap(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(60),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background — banner image if provided, else a
                // brand-coloured fallback so empty image_url
                // rows still render premium copy.
                if (offer.bannerImageUrl != null)
                  Image.network(
                    offer.bannerImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallbackBackground(),
                  )
                else
                  _fallbackBackground(),

                // Dark gradient overlay — fades from transparent
                // at the top-right to deep wine bottom-left so
                // the headline + CTA on the left sit on a
                // legible background regardless of the image.
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Colors.black.withAlpha(20),
                        Colors.black.withAlpha(180),
                      ],
                    ),
                  ),
                ),

                // Headline + countdown + CTA.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CountdownBadge(endDate: offer.endDate),
                      const Spacer(),
                      Text(
                        offer.title.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.newsreader(
                          fontSize: 22,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.05,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Get ${offer.discountPercentage}% Off',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentLight,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _PillButton(
                        label: 'Shop Now',
                        onTap: () => _onTap(context),
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

  Widget _fallbackBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF800020),
            AppColors.primary,
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Design B — Bank Offer slide (the unique factor)
// ────────────────────────────────────────────────────────────

/// Premium credit-card-style slide. Sleek metallic gradient,
/// subtle EMV chip + bank watermark, and a "Copy Code" CTA that
/// copies the promo code to the clipboard and bounces a
/// micro-snackbar.
class _BankOfferSlide extends StatefulWidget {
  const _BankOfferSlide({required this.offer});

  final PromoOffer offer;

  @override
  State<_BankOfferSlide> createState() => _BankOfferSlideState();
}

class _BankOfferSlideState extends State<_BankOfferSlide> {
  /// Which palette this slide uses. Picked deterministically
  /// from the bank name so the same issuer always paints the
  /// same gradient (HDFC=midnight blue, SBI=titanium silver,
  /// fallback=onyx). Stable across rebuilds.
  ({Color start, Color end, Color accent}) get _palette {
    final bank = widget.offer.bankName?.toUpperCase() ?? '';
    if (bank.contains('HDFC')) {
      return (
        start: const Color(0xFF0B1B3B),
        end: const Color(0xFF1F4068),
        accent: const Color(0xFFC9A86A),
      );
    }
    if (bank.contains('SBI')) {
      return (
        start: const Color(0xFF2A2F38),
        end: const Color(0xFF707A85),
        accent: const Color(0xFFE5E7EB),
      );
    }
    if (bank.contains('AXIS') || bank.contains('ICICI')) {
      return (
        start: const Color(0xFF3A0E0E),
        end: const Color(0xFF6E1A1A),
        accent: const Color(0xFFD4AF37),
      );
    }
    // Default — onyx + champagne.
    return (
      start: const Color(0xFF15161A),
      end: const Color(0xFF3B3F46),
      accent: const Color(0xFFD4AF37),
    );
  }

  Future<void> _copyCode() async {
    final code = widget.offer.promoCode;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        content: Text(
          'Code "$code" copied — paste at checkout.',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final code = widget.offer.promoCode ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.start, palette.end],
          ),
          boxShadow: [
            BoxShadow(
              color: palette.start.withAlpha(120),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Subtle metallic-sheen highlight diagonal — gives
            // the card the "this is real plastic" feel without a
            // texture image. Just a translucent linear gradient
            // overlaid on the top-left third.
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.55, 1.0],
                      colors: [
                        Colors.white.withAlpha(40),
                        Colors.white.withAlpha(0),
                        Colors.white.withAlpha(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // EMV chip watermark — bottom-right, very low alpha
            // so the text sits forward.
            Positioned(
              right: 18,
              top: 18,
              child: _ChipMark(color: palette.accent),
            ),

            // Bank watermark — bottom-right, oversized, low
            // alpha so it reads as an embossed stamp.
            Positioned(
              right: 16,
              bottom: 14,
              child: Text(
                (widget.offer.bankName ?? 'BANK').toUpperCase(),
                style: GoogleFonts.manrope(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: palette.accent.withAlpha(45),
                ),
              ),
            ),

            // Content layer.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accent.withAlpha(40),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: palette.accent.withAlpha(120),
                      ),
                    ),
                    child: Text(
                      'BANK OFFER',
                      style: GoogleFonts.manrope(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: palette.accent,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Instant ${widget.offer.discountPercentage}% Off',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.newsreader(
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.0,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.offer.bankName != null
                        ? 'on ${widget.offer.bankName} Credit Cards'
                        : (widget.offer.description ?? 'Bank Card Offer'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(220),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (code.isNotEmpty)
                    _CopyCodePill(
                      code: code,
                      accent: palette.accent,
                      onTap: _copyCode,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Sub-widgets
// ────────────────────────────────────────────────────────────

/// Live countdown badge for flash-sale slides — ticks once a
/// second. Hides itself if the offer is already expired.
class _CountdownBadge extends StatefulWidget {
  const _CountdownBadge({required this.endDate});

  final DateTime endDate;

  @override
  State<_CountdownBadge> createState() => _CountdownBadgeState();
}

class _CountdownBadgeState extends State<_CountdownBadge> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final diff = widget.endDate.difference(DateTime.now());
    if (!mounted) return;
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) return const SizedBox.shrink();

    final h = _remaining.inHours.toString().padLeft(2, '0');
    final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    // Show DAYS instead of just hours when the offer is more
    // than a day out — keeps the badge readable without ticking
    // a 72-hour string.
    final daysLeft = _remaining.inDays;
    final body = daysLeft >= 1
        ? 'ENDS IN ${daysLeft}d ${(_remaining.inHours % 24).toString().padLeft(2, '0')}h'
        : 'ENDS IN $h:$m:$s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(120),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 12,
            color: Colors.white.withAlpha(220),
          ),
          const SizedBox(width: 6),
          Text(
            body,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CopyCodePill extends StatelessWidget {
  const _CopyCodePill({
    required this.code,
    required this.accent,
    required this.onTap,
  });

  final String code;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.copy_rounded,
                size: 14,
                color: Colors.black,
              ),
              const SizedBox(width: 6),
              Text(
                'COPY CODE: $code',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// EMV-chip-style watermark — the gold square with a stylised
/// pin-grid that sits on every credit card. Drawn with a
/// CustomPaint so we don't ship an asset for it.
class _ChipMark extends StatelessWidget {
  const _ChipMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 22,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withAlpha(220),
            color.withAlpha(140),
          ],
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black.withAlpha(40)),
      ),
      child: CustomPaint(painter: _ChipGridPainter()),
    );
  }
}

class _ChipGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withAlpha(50)
      ..strokeWidth = 0.6;
    // Two horizontal divider lines.
    final yStep = size.height / 3;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(0, yStep * i),
        Offset(size.width, yStep * i),
        paint,
      );
    }
    // One vertical divider down the centre.
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
