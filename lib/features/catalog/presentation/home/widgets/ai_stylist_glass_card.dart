import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/theme.dart';

/// Feature 3 — Glowing AI Stylist widget.
///
/// Glassmorphism hero card: a colourful animated abstract
/// background gets blurred behind a frosted glass surface
/// (via [BackdropFilter] + [ImageFilter.blur]). A 3D-popped
/// "Start Chat" button sits inside; tapping it routes to the
/// existing Outfitly AI screen at `/outfitly-ai`.
///
/// The animated background is a slow-rotating multi-stop
/// gradient driven by an [AnimationController] in repeat mode —
/// gives the card a subtle, alive quality without dragging in
/// an image asset or a Lottie file.
class AiStylistGlassCard extends StatefulWidget {
  const AiStylistGlassCard({super.key});

  @override
  State<AiStylistGlassCard> createState() => _AiStylistGlassCardState();
}

class _AiStylistGlassCardState extends State<AiStylistGlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool v) => setState(() => _pressed = v);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Rotate the gradient anchor over time so the
            // background reads as a slow, dreamy lava lamp
            // behind the glass.
            final t = _controller.value;
            return Stack(
              children: [
                // Animated abstract gradient — the "wallpaper"
                // behind the glass. Three colour stops, with
                // their alignment anchors orbiting via sin/cos.
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: _orbit(t, 0),
                        end: _orbit(t, 0.5),
                        colors: const [
                          Color(0xFFFF6E91),
                          Color(0xFF8E4180),
                          Color(0xFF3AA0E0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Decorative blurry orbs floating on top.
                Positioned(
                  top: -30,
                  right: -20,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFD58F).withAlpha(140),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  left: -30,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF7EC9B5).withAlpha(140),
                    ),
                  ),
                ),
                // Glassmorphism layer — BackdropFilter over a
                // translucent fill creates the frosted-glass
                // feel. Inset by 1 to dodge the parent
                // ClipRRect's rounded corners.
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        border: Border.all(
                          color: Colors.white.withAlpha(80),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(70),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withAlpha(120),
                              ),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(50),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withAlpha(90),
                              ),
                            ),
                            child: Text(
                              'AI STYLIST',
                              style: GoogleFonts.manrope(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "Can't decide what\nto wear?",
                        style: GoogleFonts.newsreader(
                          fontSize: 26,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                          height: 1.05,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ask your AI Stylist — combos from your closet, '
                        'occasion-led picks, palettes that work for you.',
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          color: Colors.white.withAlpha(225),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _StartChatButton(
                        pressed: _pressed,
                        onTapDown: (_) => _setPressed(true),
                        onTapUp: (_) => _setPressed(false),
                        onTapCancel: () => _setPressed(false),
                        onTap: () => context.push('/outfitly-ai'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Returns a unit-circle [Alignment] offset by `phase` (0–1),
  /// modulated by the controller's `t` (0–1). Used to orbit the
  /// gradient anchors so the wallpaper breathes.
  Alignment _orbit(double t, double phase) {
    final theta = (t + phase) * 2 * math.pi;
    final x = math.cos(theta) * 0.9;
    final y = math.sin(theta) * 0.9;
    return Alignment(x, y);
  }
}

class _StartChatButton extends StatelessWidget {
  const _StartChatButton({
    required this.pressed,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
    required this.onTap,
  });

  final bool pressed;
  final ValueChanged<TapDownDetails> onTapDown;
  final ValueChanged<TapUpDetails> onTapUp;
  final VoidCallback onTapCancel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: onTapDown,
        onTapUp: onTapUp,
        onTapCancel: onTapCancel,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8E4180).withAlpha(140),
                blurRadius: pressed ? 6 : 14,
                offset: Offset(0, pressed ? 3 : 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chat_bubble_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Start Chat',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: AppColors.primary,
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
