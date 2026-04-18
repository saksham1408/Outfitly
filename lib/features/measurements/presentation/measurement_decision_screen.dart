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
  late final Animation<double> _fadeAnimation;
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
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideA = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));
    _slideB = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // ── Icon ──
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.straighten_rounded,
                    size: 44,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'How would you like to\nprovide your measurements?',
                style: GoogleFonts.newsreader(
                  fontSize: 26,
                  fontStyle: FontStyle.italic,
                  color: AppColors.primary,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'We need your exact measurements to craft\nyour outfit to perfection.',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 2),

              // ── Option A: Manual ──
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

              const SizedBox(height: 16),

              // ── Option B: Tailor ──
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

              const Spacer(flex: 1),
            ],
          ),
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
        padding: const EdgeInsets.all(20),
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
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent
                    ? Colors.white.withAlpha(20)
                    : AppColors.primary.withAlpha(10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 26,
                color: accent ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
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
                  const SizedBox(height: 4),
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
              size: 16,
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
