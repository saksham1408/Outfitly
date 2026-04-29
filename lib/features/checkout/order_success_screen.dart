import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme.dart';

class OrderSuccessScreen extends StatefulWidget {
  /// Non-null when the order was placed with a home-tailor-visit. The
  /// screen renders an extra primary CTA that deep-links into the live
  /// Realtime tracker so the customer can watch the Partner advance
  /// the appointment through `pending → accepted → en_route → arrived
  /// → completed`. Without it the customer was effectively blind to
  /// the dispatch status — they'd just see the static "Pending
  /// Approval" garment-order screen and assume nothing was happening.
  const OrderSuccessScreen({super.key, this.tailorVisitId});

  final String? tailorVisitId;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _checkController;
  late final AnimationController _fadeController;
  late final Animation<double> _checkScale;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _checkScale = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
    _fadeIn = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Stagger animations
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _checkController.forward();
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _checkController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The button stack used to be three rows: Track Tailor Visit
    // (conditional), Track My Order, Continue Shopping. On a 6.1" iPhone
    // 17 Pro that pushed the bottom Spacer below the safe area and
    // triggered Flutter's "overflowed by N pixels" debug paint. Switched
    // the body from a fixed Column-with-Spacers layout to a centered
    // ConstrainedBox inside a SingleChildScrollView so the content
    // always vertically centers when it fits, and gracefully scrolls
    // when it doesn't (e.g. with the extra tailor-visit CTA, smaller
    // viewports, or a future add).
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // ── Animated Checkmark ──
                      ScaleTransition(
                        scale: _checkScale,
                        child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(40),
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── Text Content ──
              FadeTransition(
                opacity: _fadeIn,
                child: Column(
                  children: [
                    Text(
                      'Order Submitted!',
                      style: GoogleFonts.newsreader(
                        fontSize: 32,
                        fontStyle: FontStyle.italic,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your bespoke order is awaiting\nadmin approval.',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        color: AppColors.textTertiary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 2,
                      width: 48,
                      color: AppColors.accent,
                    ),

                    const SizedBox(height: 32),

                    // ── Status Info ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _statusRow(
                            '⏳',
                            'Pending Approval',
                            'Our team will review and confirm your order within 24 hours.',
                          ),
                          const SizedBox(height: 16),
                          _statusRow(
                            '🔔',
                            'Real-time Updates',
                            'Track every stage — from fabric sourcing to delivery.',
                          ),
                          const SizedBox(height: 16),
                          _statusRow(
                            '✂️',
                            'Bespoke Crafting',
                            'Estimated 10–14 working days from acceptance.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // ── Buttons ──
              FadeTransition(
                opacity: _fadeIn,
                child: Column(
                  children: [
                    // Tailor-visit-only CTA. Promoted to the *primary*
                    // slot when present because it's the live one — the
                    // customer's most valuable next click is watching
                    // the Partner accept and head over, not staring at
                    // the static "Pending Approval" garment status.
                    if (widget.tailorVisitId != null) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => context.go(
                            '/tailor-visit/${widget.tailorVisitId}',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(
                            Icons.location_searching_rounded,
                            size: 18,
                          ),
                          label: Text(
                            'TRACK TAILOR VISIT',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => context.go('/home'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'TRACK MY ORDER',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/home'),
                      child: Text(
                        'Continue Shopping',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusRow(String emoji, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
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
    );
  }
}
