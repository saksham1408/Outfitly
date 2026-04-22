import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';

/// Animated brand splash — the first surface users see on cold launch.
///
/// Behaviour:
///   * An [AnimationController] drives a combined fade-in + slight
///     scale-up of the logo block. The whole animation finishes in
///     ~900ms; the screen then holds for the remainder of a 3-second
///     window before navigating forward.
///   * Navigation uses `context.go()` (not `push`) so the splash is
///     REPLACED in the stack — users cannot swipe/tap back to it.
///   * Destination is auth-aware: existing Supabase session → `/home`,
///     otherwise `/login`. The router's redirect gate gives `/` a free
///     pass so this screen can always render before we branch.
///
/// The deep-forest primary color is reused from the hero banner to tie
/// the splash into the rest of the VASTRAHUB/Outfitly brand palette.
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
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle radial glow behind the logo block so the splash
            // reads as luxe rather than a flat solid.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.9,
                    colors: [
                      AppColors.primaryLight.withAlpha(120),
                      AppColors.primary,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ring + icon badge. The concentric circles give
                      // the mark presence at splash scale without
                      // needing a bespoke logo asset.
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(22),
                          border: Border.all(
                            color: Colors.white.withAlpha(55),
                            width: 1.2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withAlpha(140),
                                blurRadius: 32,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.checkroom_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Wordmark — italic serif in the hero treatment
                      // used on the home hero banner so the brand feels
                      // consistent between splash and first screen.
                      Text(
                        'Vastrahub',
                        style: GoogleFonts.newsreader(
                          fontSize: 46,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Tagline in sans to balance the italic wordmark.
                      Text(
                        'BESPOKE FASHION · DELIVERED',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withAlpha(200),
                          letterSpacing: 2.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Tiny footer accent — spins up *after* the main block is
            // visible so the eye lands on the logo first.
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
                        Colors.white.withAlpha(140),
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
