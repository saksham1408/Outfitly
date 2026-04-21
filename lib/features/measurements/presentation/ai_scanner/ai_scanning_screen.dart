import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme.dart';
import '../../../checkout/models/order_payload.dart';
import '../../data/ai_measurement_service.dart';
import '../../models/measurement_profile.dart';
import 'ai_camera_screen.dart';

/// The "futuristic" intermission between capture and review.
///
/// Plays a cycling status copy and a laser-line scanning animation on
/// top of the two captured frames while [AiMeasurementService] does its
/// (currently mocked) 4-second compute. Once the profile resolves we
/// replace the current route with the review screen so the back button
/// returns the user to the decision screen, not the loading state.
class AiScanningScreen extends StatefulWidget {
  final AiScanPayload payload;

  const AiScanningScreen({super.key, required this.payload});

  @override
  State<AiScanningScreen> createState() => _AiScanningScreenState();
}

class _AiScanningScreenState extends State<AiScanningScreen>
    with TickerProviderStateMixin {
  late final AnimationController _scanController;
  late final Timer _copyTimer;
  int _copyIndex = 0;
  bool _completed = false;

  static const _statusCopy = [
    'Mapping body contours…',
    'Detecting shoulder width…',
    'Calculating inseam…',
    'Reading torso proportions…',
    'Generating bespoke profile…',
    'Finalising measurements…',
  ];

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _copyTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      setState(() {
        _copyIndex = (_copyIndex + 1) % _statusCopy.length;
      });
    });

    _runScan();
  }

  Future<void> _runScan() async {
    final service = AiMeasurementService();
    final MeasurementProfile profile;
    try {
      profile = await service.calculateMeasurements(
        widget.payload.frontImage,
        widget.payload.sideImage,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
      context.pop();
      return;
    }
    if (!mounted) return;
    setState(() => _completed = true);

    // Short beat on the 100% state before handing off.
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    context.pushReplacement(
      '/measurements/ai-scan-review',
      extra: AiReviewPayload(order: widget.payload.order, profile: profile),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _copyTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              // ── Header ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withAlpha(30)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _completed
                                ? AppColors.success
                                : AppColors.accentContainer,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _completed ? 'SCAN COMPLETE' : 'SCANNING',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _completed ? '100%' : '${_progressPercent()}%',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentContainer,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Dual image viewer w/ laser sweep ──
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _scanTile(
                        widget.payload.frontImage,
                        'FRONT',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _scanTile(
                        widget.payload.sideImage,
                        'SIDE',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Status copy ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _completed
                      ? 'Your bespoke profile is ready.'
                      : _statusCopy[_copyIndex],
                  key: ValueKey(_completed ? 'done' : _copyIndex),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.newsreader(
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _completed
                    ? 'Taking you to the review screen…'
                    : 'Our AI is reading over 40 body points.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: Colors.white.withAlpha(170),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _progressPercent() {
    // Rough visual progress tied to the scan timer (4s total).
    // Not exact — just gives the header a "moving" number.
    final v = (_copyIndex + 1) / _statusCopy.length;
    return (v * 100).clamp(8, 95).toInt();
  }

  Widget _scanTile(File image, String label) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accentContainer.withAlpha(90)),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentContainer.withAlpha(40),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Captured photo
            Image.file(image, fit: BoxFit.cover),

            // Darken for contrast
            Container(color: Colors.black.withAlpha(80)),

            // Mesh grid overlay
            IgnorePointer(
              child: CustomPaint(painter: _GridPainter()),
            ),

            // Laser sweep
            AnimatedBuilder(
              animation: _scanController,
              builder: (context, _) {
                return IgnorePointer(
                  child: CustomPaint(
                    painter: _LaserPainter(_scanController.value),
                  ),
                );
              },
            ),

            // Label pill
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(140),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.accentContainer.withAlpha(80),
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                    color: AppColors.accentContainer,
                  ),
                ),
              ),
            ),

            if (_completed)
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(220),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withAlpha(180),
                        blurRadius: 18,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Light dotted grid to give the captured photo a "technical" feel.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentContainer.withAlpha(36)
      ..strokeWidth = 0.8;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Horizontal laser line that sweeps top-to-bottom. The 0→1 [t] is
/// driven by the parent's [AnimationController] (reversing), which
/// produces the natural up-and-down scan motion.
class _LaserPainter extends CustomPainter {
  final double t;
  _LaserPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final y = t * size.height;

    // Bright core line
    final corePaint = Paint()
      ..color = AppColors.accentContainer
      ..strokeWidth = 1.6;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), corePaint);

    // Soft bloom band
    final bandRect = Rect.fromLTWH(0, y - 14, size.width, 28);
    final bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.accentContainer.withAlpha(0),
          AppColors.accentContainer.withAlpha(80),
          AppColors.accentContainer.withAlpha(0),
        ],
      ).createShader(bandRect);
    canvas.drawRect(bandRect, bandPaint);
  }

  @override
  bool shouldRepaint(covariant _LaserPainter oldDelegate) => oldDelegate.t != t;
}

/// Carrier passed into the review screen. Keeps the order-payload +
/// freshly-calculated profile together in a typed object instead of a
/// loose `List` or `Map`.
class AiReviewPayload {
  final OrderPayload? order;
  final MeasurementProfile profile;

  const AiReviewPayload({required this.order, required this.profile});
}
