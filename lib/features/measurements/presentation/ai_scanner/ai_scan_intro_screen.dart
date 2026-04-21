import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme.dart';
import '../../../checkout/models/order_payload.dart';

/// Primes the user before we launch the camera: explains the two shots,
/// asks them to wear fitted clothing, and confirms they're ready. On
/// tap we route to the camera screen, carrying the [OrderPayload]
/// through so the downstream review screen can continue to checkout.
class AiScanIntroScreen extends StatelessWidget {
  final OrderPayload? payload;

  const AiScanIntroScreen({super.key, this.payload});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'AI Body Scan',
          style: GoogleFonts.newsreader(
            fontSize: 22,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // ── Hero ──
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primaryDark,
                            AppColors.primary,
                            AppColors.primaryLight,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(28),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.accessibility_new_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Two quick photos.\nA perfect fit.',
                                  style: GoogleFonts.newsreader(
                                    fontSize: 22,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Our AI maps over 40 body points from just a front and side photo — no tape, no guessing.',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: Colors.white.withAlpha(220),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'BEFORE YOU BEGIN',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _tip(
                      icon: Icons.checkroom_rounded,
                      title: 'Wear fitted clothing',
                      body:
                          'Loose clothes throw off the measurement — snug, solid-coloured is best.',
                    ),
                    _tip(
                      icon: Icons.wb_sunny_rounded,
                      title: 'Find good lighting',
                      body:
                          'A well-lit, plain background in front of you helps the AI see you clearly.',
                    ),
                    _tip(
                      icon: Icons.phone_iphone_rounded,
                      title: 'Prop the phone up',
                      body:
                          'Rest your phone 6–7 ft (2 m) away at waist height. Ask someone to tap capture if you can.',
                    ),
                    _tip(
                      icon: Icons.accessibility_rounded,
                      title: 'Stand tall, arms slightly out',
                      body:
                          'We\'ll guide you through a front shot and a side shot with an on-screen outline.',
                    ),

                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.accent.withAlpha(40),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your photos never leave your device in identifiable form — we only keep the measurements.',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppColors.accent,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push(
                      '/measurements/ai-scan-camera',
                      extra: payload,
                    );
                  },
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: Text(
                    'I\'M READY — START SCAN',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tip({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withAlpha(60)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.textTertiary,
                    ),
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
