import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../data/vision_service.dart';
import '../models/recreated_design.dart';
import 'recreate_look_screen.dart';
import 'recreated_design_studio_screen.dart';

/// Step 3 — the "AI is thinking" interlude.
///
/// Two things happen on this screen, in parallel:
///
///   * The Gemini Vision API call is fired in [initState]. Its result
///     is awaited but the UI doesn't block on it — it just waits for
///     a minimum dwell of [_minimumDwell] so the laser-scan animation
///     doesn't flicker by on a fast network. When both the API and
///     the dwell complete, we [pushReplacement] to the result screen.
///
///   * A vertical laser line scans up and down the user's photo and a
///     stack of phrases cycles below ("Analyzing fabric drape…",
///     "Matching collar patterns…"). The animation is purely cosmetic
///     and runs even if the API call has long since returned.
///
/// We use `pushReplacement` (not `push`) to land on this screen and
/// to leave it, so the back gesture skips the analyzer entirely —
/// hopping back from the result lands at home, not on a stale
/// scanning UI.
class AnalyzingLookScreen extends StatefulWidget {
  const AnalyzingLookScreen({super.key, required this.request});

  final RecreateLookRequest request;

  @override
  State<AnalyzingLookScreen> createState() => _AnalyzingLookScreenState();
}

class _AnalyzingLookScreenState extends State<AnalyzingLookScreen>
    with TickerProviderStateMixin {
  static const _phrases = <String>[
    'Analyzing fabric drape…',
    'Matching collar patterns…',
    'Reading sleeve cut…',
    'Calculating budget-friendly alternatives…',
    'Drafting your custom blueprint…',
  ];

  /// Minimum on-screen time so the scan animation registers visually
  /// even on the fast path. The Gemini call typically takes 3–6s; on
  /// a flaky network it can take 12s+. Either way we land within the
  /// max(_, dwell) window.
  static const _minimumDwell = Duration(seconds: 3);

  late final AnimationController _scanController;
  late final Timer _phraseTimer;
  int _phraseIndex = 0;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _phraseTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!mounted) return;
      setState(() => _phraseIndex = (_phraseIndex + 1) % _phrases.length);
    });

    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    final service = VisionService();
    final results = await Future.wait<Object?>([
      service.analyzeOutfit(
        widget.request.image,
        widget.request.budget,
        widget.request.occasion,
      ),
      Future<void>.delayed(_minimumDwell),
    ]);
    if (!mounted) return;

    final design = results[0] as RecreatedDesign;
    context.pushReplacement(
      '/recreate-look/result',
      extra: RecreatedDesignResult(
        image: widget.request.image,
        design: design,
      ),
    );
  }

  @override
  void dispose() {
    _phraseTimer.cancel();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                'AI LOOK RECREATOR',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: AppColors.accentContainer,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Reverse-engineering this look',
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  fontSize: 22,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 22),

              // ── Image with laser scan ──
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(widget.request.image, fit: BoxFit.cover),
                      // Subtle dark veil so the laser reads clearly.
                      Container(color: Colors.black.withAlpha(60)),
                      AnimatedBuilder(
                        animation: _scanController,
                        builder: (_, _) =>
                            _LaserOverlay(progress: _scanController.value),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ── Cycling phrase ──
              SizedBox(
                height: 28,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _phrases[_phraseIndex],
                    key: ValueKey(_phraseIndex),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hold tight — this usually takes a few seconds.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: Colors.white.withAlpha(150),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// The horizontal laser line + glow band that animates over the image.
///
/// [progress] is the current `_scanController.value` in `[0..1]` —
/// because the controller `repeat(reverse: true)` swings the value
/// back and forth, we only need to map progress → vertical offset.
class _LaserOverlay extends StatelessWidget {
  const _LaserOverlay({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final h = constraints.maxHeight;
      final y = h * progress;
      return Stack(
        children: [
          // Soft glow band centred on the laser.
          Positioned(
            top: y - 60,
            left: 0,
            right: 0,
            height: 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.accentContainer.withAlpha(0),
                      AppColors.accentContainer.withAlpha(70),
                      AppColors.accentContainer.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The crisp 2px laser itself.
          Positioned(
            top: y,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.accentContainer,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentContainer.withAlpha(180),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}
