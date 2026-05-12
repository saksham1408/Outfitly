import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mandate 4 — 3D Tactile Quick-Action Dock.
///
/// A 2×2 grid of large, rounded-rect buttons styled to look
/// physical. Each tile:
///
///   * Top-to-bottom linear gradient (light to dark) so the
///     surface reads as a curved button cap.
///   * Light 1px inner border at the top — "catches the light".
///   * Heavy bottom shadow (`Offset(0, 8)`) at rest, softens
///     to `Offset(0, 2)` on press to sell the depressed state.
///   * An [AnimatedScale] inner element shrinking from 1.0 →
///     0.95 on `onTapDown` and springing back on release.
///
/// All four destinations route to existing surfaces:
///   * 👗 Digitize       → /wardrobe
///   * ✂️ Book Tailor   → /custom-stitching/book
///   * 🤝 Friend's Closet → /social
///   * 🔥 Combos         → /combo-selection
class TactileQuickDock extends StatelessWidget {
  const TactileQuickDock({super.key});

  static const _tiles = <_TactileSpec>[
    _TactileSpec(
      emoji: '👗',
      title: 'Digitize',
      subtitle: 'Closet',
      route: '/wardrobe',
      light: Color(0xFFF472B6),
      dark: Color(0xFF9D174D),
    ),
    _TactileSpec(
      emoji: '✂️',
      title: 'Book',
      subtitle: 'Tailor',
      route: '/custom-stitching/book',
      light: Color(0xFFFBBF24),
      dark: Color(0xFF92400E),
    ),
    _TactileSpec(
      emoji: '🤝',
      title: "Friend's",
      subtitle: 'Closet',
      route: '/social',
      light: Color(0xFF60A5FA),
      dark: Color(0xFF1E3A8A),
    ),
    _TactileSpec(
      emoji: '🔥',
      title: 'Family',
      subtitle: 'Combos',
      route: '/combo-selection',
      light: Color(0xFFFB923C),
      dark: Color(0xFF9A1F0B),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.55,
        ),
        itemCount: _tiles.length,
        itemBuilder: (context, i) => _TactileButton(spec: _tiles[i]),
      ),
    );
  }
}

class _TactileSpec {
  const _TactileSpec({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.light,
    required this.dark,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final String route;
  final Color light;
  final Color dark;
}

class _TactileButton extends StatefulWidget {
  const _TactileButton({required this.spec});

  final _TactileSpec spec;

  @override
  State<_TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<_TactileButton> {
  bool _pressed = false;

  void _setPressed(bool v) => setState(() => _pressed = v);

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: () => context.push(spec.route),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            // Top → bottom gradient (light → dark) so the
            // surface curves toward the bottom like a real
            // button cap.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [spec.light, spec.dark],
            ),
            // Hairline top border catches the light + reads as
            // a bevel.
            border: Border(
              top: BorderSide(
                color: Colors.white.withAlpha(80),
                width: 1,
              ),
              left: BorderSide(
                color: Colors.white.withAlpha(50),
                width: 1,
              ),
              right: BorderSide(
                color: Colors.black.withAlpha(60),
                width: 1,
              ),
              bottom: BorderSide(
                color: Colors.black.withAlpha(80),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: spec.dark.withAlpha(_pressed ? 80 : 180),
                blurRadius: _pressed ? 8 : 18,
                offset: Offset(0, _pressed ? 2 : 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Inner top highlight — a soft radial gradient
              // anchored to top-left so the cap reads "lit".
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: RadialGradient(
                        center: const Alignment(-0.5, -0.7),
                        radius: 1.1,
                        colors: [
                          Colors.white.withAlpha(80),
                          Colors.white.withAlpha(0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Text(
                      spec.emoji,
                      style: const TextStyle(fontSize: 30),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            spec.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            spec.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withAlpha(220),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
