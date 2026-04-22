import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/supabase_client.dart';

/// Animated brand splash — the first Flutter-rendered surface users see
/// on cold launch.
///
/// Behaviour:
///   * An [AnimationController] drives a combined fade-in + slight
///     scale-up of the Vastrahub logo. The animation finishes in
///     ~900ms; the screen then holds for the remainder of a 3-second
///     window before navigating forward.
///   * Navigation uses `context.go()` (not `push`) so the splash is
///     REPLACED in the stack — users cannot swipe/tap back to it.
///   * Destination is auth-aware: existing Supabase session → `/home`,
///     otherwise `/login`. The router's redirect gate gives `/` a free
///     pass so this screen can always render before we branch.
///
/// The crisp-white backdrop mirrors the launcher-icon + native-splash
/// config so the OS → native splash → animated Dart splash handoff
/// reads as a single seamless moment (no colour flash between stages).
/// The Vastrahub mark is self-contained — hanger motif + "वस्त्र Hub"
/// wordmark + "FASHION FOR EVERY YOU" tagline are all baked into the
/// PNG — so we render it 1:1 without any surrounding ring, wordmark
/// overlay, or secondary text.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Total time the user dwells on the splash (including the intro
  /// animation). The protocol asks for 2–3 seconds — 3s gives the
  /// animation room to breathe without feeling sluggish.
  static const Duration _holdDuration = Duration(seconds: 3);

  /// Pure white matching the launcher-icon background and the logo's
  /// own canvas. Consistent across native splash + Dart splash so the
  /// transition between stages is invisible.
  static const Color _brandBackground = Color(0xFFFFFFFF);

  /// Warm off-white for the radial-glow centre — stops the flat
  /// white backdrop from reading as sterile / office-document. Pulled
  /// a half-step off pure white; enough to feel intentional without
  /// competing with the black mark for attention.
  static const Color _brandGlow = Color(0xFFF5F1EB);

  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();

    _navTimer = Timer(_holdDuration, _goNext);
  }

  /// Auth-aware forward navigation. Uses `go()` to replace the route
  /// so the back gesture can't bounce the user back onto the splash.
  void _goNext() {
    if (!mounted) return;
    final session = AppSupabase.client.auth.currentSession;
    context.go(session != null ? '/home' : '/login');
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _brandBackground,
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle warm-white radial glow so the flat backdrop reads
            // luxe rather than sterile. Both stops are within touching
            // distance of pure white — just enough depth for the eye
            // to land on the centred mark.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.9,
                    colors: [_brandGlow, _brandBackground],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  // Render the Vastrahub brand mark as-is — no extra
                  // wordmark or tagline around it, since the logo
                  // already contains "वस्त्र Hub" + "FASHION FOR EVERY
                  // YOU". cacheWidth/Height keep the decoded bitmap at
                  // display size so we don't blow 4MB of memory on a
                  // 1024² source when we only need ~260 points.
                  child: Image.asset(
                    'assets/branding/vastrahub_icon.png',
                    width: 260,
                    height: 260,
                    fit: BoxFit.contain,
                    cacheWidth: 520,
                    cacheHeight: 520,
                  ),
                ),
              ),
            ),
            // Tiny footer accent — spins up *after* the main block is
            // visible so the eye lands on the logo first. Translucent
            // black stroke so it reads against the white backdrop
            // without feeling heavy.
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: FadeTransition(
                opacity: _fade,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.black.withAlpha(140),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
