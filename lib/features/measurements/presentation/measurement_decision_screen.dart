import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../../checkout/models/order_payload.dart';

class MeasurementDecisionScreen extends StatefulWidget {
  final OrderPayload? payload;

  const MeasurementDecisionScreen({super.key, this.payload});

  @override
  State<MeasurementDecisionScreen> createState() =>
      _MeasurementDecisionScreenState();
}

class _MeasurementDecisionScreenState extends State<MeasurementDecisionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final AnimationController _sparkleController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideHero;
  late final Animation<Offset> _slideA;
  late final Animation<Offset> _slideB;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideHero = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    ));
    _slideA = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.25, 0.75, curve: Curves.easeOutCubic),
    ));
    _slideB = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Measurements',
          style: GoogleFonts.newsreader(
            fontSize: 22,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // ── Headline ──
            const SizedBox(height: 4),
            Text(
              'How would you like to\nprovide your measurements?',
              style: GoogleFonts.newsreader(
                fontSize: 24,
                fontStyle: FontStyle.italic,
                color: AppColors.primary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick the method that works best for you — we\'ll tailor your outfit to the millimetre.',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AppColors.textTertiary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // ── Option A (Flagship): AI Body Scan ──
            SlideTransition(
              position: _slideHero,
              child: _AiScanHeroCard(
                sparkleController: _sparkleController,
                onTap: () {
                  final payload = widget.payload;
                  if (payload != null) payload.measurementMethod = 'ai_scan';
                  context.push('/measurements/ai-scan-intro', extra: payload);
                },
              ),
            ),

            const SizedBox(height: 20),

            // Subtle separator
            Row(
              children: [
                Expanded(
                  child: Divider(color: AppColors.border.withAlpha(80)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(color: AppColors.border.withAlpha(80)),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Option B: Manual ──
            SlideTransition(
              position: _slideA,
              child: _optionCard(
                icon: Icons.edit_note_rounded,
                title: 'Enter Manually',
                subtitle:
                    'I know my measurements — chest, waist, hips, inseam, etc.',
                accent: false,
                onTap: () {
                  final payload = widget.payload;
                  if (payload != null) payload.measurementMethod = 'manual';
                  context.push('/measurements/manual', extra: payload);
                },
              ),
            ),

            const SizedBox(height: 14),

            // ── Option C: Tailor ──
            SlideTransition(
              position: _slideB,
              child: _optionCard(
                icon: Icons.person_pin_circle_rounded,
                title: 'Book Home Tailor',
                subtitle:
                    'We\'ll send a professional tailor to your doorstep — free of charge.',
                accent: true,
                badge: 'FREE',
                onTap: () {
                  final payload = widget.payload;
                  if (payload != null) payload.measurementMethod = 'tailor';
                  context.push('/measurements/book-tailor', extra: payload);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool accent,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: accent ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent ? AppColors.primary : AppColors.border.withAlpha(80),
          ),
          boxShadow: [
            BoxShadow(
              color: accent
                  ? AppColors.primary.withAlpha(25)
                  : Colors.black.withAlpha(6),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent
                    ? Colors.white.withAlpha(20)
                    : AppColors.primary.withAlpha(10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                size: 24,
                color: accent ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: accent ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.manrope(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: accent
                          ? Colors.white.withAlpha(180)
                          : AppColors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: accent
                  ? Colors.white.withAlpha(150)
                  : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Flagship card for the AI Body Scan feature. Uses a dark gradient, subtle
/// rotating sparkle chips, a scanning-line motif, and a RECOMMENDED badge
/// to signal premium status over the other two measurement methods.
class _AiScanHeroCard extends StatelessWidget {
  final AnimationController sparkleController;
  final VoidCallback onTap;

  const _AiScanHeroCard({
    required this.sparkleController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [
              AppColors.primaryDark,
              AppColors.primary,
              AppColors.primaryLight,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(60),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative scanning lines in the background
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: AnimatedBuilder(
                  animation: sparkleController,
                  builder: (_, __) {
                    return CustomPaint(
                      painter: _ScanLinesPainter(sparkleController.value),
                    );
                  },
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(28),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withAlpha(40),
                        ),
                      ),
                      child: const Icon(
                        Icons.accessibility_new_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'RECOMMENDED',
                              style: GoogleFonts.manrope(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'AI Body Scan',
                            style: GoogleFonts.newsreader(
                              fontSize: 22,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: AppColors.accentContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Get perfectly measured in 30 seconds using just your camera. No tape required.',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: Colors.white.withAlpha(220),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _featurePill(Icons.bolt_rounded, '30 sec'),
                    const SizedBox(width: 8),
                    _featurePill(Icons.precision_manufacturing_rounded, 'AI'),
                    const SizedBox(width: 8),
                    _featurePill(Icons.lock_outline_rounded, 'Private'),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'START',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: AppColors.primaryDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _featurePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white.withAlpha(220)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(230),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin horizontal "scan lines" that sweep across the card background,
/// adding a quiet sense of motion without competing with the content.
class _ScanLinesPainter extends CustomPainter {
  final double t;
  _ScanLinesPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(16)
      ..strokeWidth = 1;

    for (int i = 0; i < 6; i++) {
      final offset = (t + i / 6) % 1.0;
      final y = offset * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanLinesPainter old) => old.t != t;
}
