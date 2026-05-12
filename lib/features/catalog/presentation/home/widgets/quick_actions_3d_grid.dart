import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Feature 2 — 3D Quick Action Grid.
///
/// A 2×2 grid of tactile, depressible "popped" buttons for the
/// app's four primary user-loops. Each tile combines:
///
///   * A two-stop gradient interior (unique palette per tile).
///   * A heavy bottom shadow + a soft inner highlight to give
///     the physical "raised plastic" look.
///   * An [InkWell] that drives a press-down animation on tap so
///     the button visually depresses, then springs back as it
///     navigates. The animation is implemented via an
///     [AnimatedScale] keyed to a local _pressed flag.
///
/// All four destinations route to existing surfaces:
///   * 👗 Digitize Closet → /wardrobe (WardrobeInventoryScreen)
///   * ✂️ Book Tailor    → /custom-stitching/book (the booking form)
///   * 🤝 Friend's Closet → /social (social dashboard)
///   * 🔥 Active Sales   → /offers (promo offers dashboard)
class QuickActions3DGrid extends StatelessWidget {
  const QuickActions3DGrid({super.key});

  static const _tiles = <_QuickActionSpec>[
    _QuickActionSpec(
      emoji: '👗',
      title: 'Digitize\nCloset',
      subtitle: 'Snap your wardrobe',
      route: '/wardrobe',
      gradient: [Color(0xFF8E4180), Color(0xFFD96AA0)],
    ),
    _QuickActionSpec(
      emoji: '✂️',
      title: 'Book\nTailor',
      subtitle: 'Home visit, free',
      route: '/custom-stitching/book',
      gradient: [Color(0xFFB8860B), Color(0xFFF0C75D)],
    ),
    _QuickActionSpec(
      emoji: '🤝',
      title: "Friend's\nCloset",
      subtitle: 'Borrow what you love',
      route: '/social',
      gradient: [Color(0xFF1F4068), Color(0xFF3AA0E0)],
    ),
    _QuickActionSpec(
      emoji: '🔥',
      title: 'Active\nSales',
      subtitle: 'Limited-time edits',
      route: '/offers',
      gradient: [Color(0xFFC03A2B), Color(0xFFFB8C5C)],
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
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          // 3D tiles need height to look pop-art-y rather than
          // squashed — 1.32 keeps them taller than square.
          childAspectRatio: 1.05,
        ),
        itemCount: _tiles.length,
        itemBuilder: (context, i) => _QuickActionTile(spec: _tiles[i]),
      ),
    );
  }
}

class _QuickActionSpec {
  const _QuickActionSpec({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.gradient,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final String route;
  final List<Color> gradient;
}

/// Single 3D button. Implements the press-depress feedback via
/// [AnimatedScale] + a local _pressed flag toggled by the
/// gesture callbacks. The shadow also softens on press, which
/// is the visual cue that sells the "physical button" trick.
class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({required this.spec});

  final _QuickActionSpec spec;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  void _setPressed(bool v) => setState(() => _pressed = v);

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () => context.push(spec.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: spec.gradient,
            ),
            boxShadow: [
              // Heavy bottom shadow — the "pop" trick. Hardens
              // on rest, softens + shifts up on press.
              BoxShadow(
                color: spec.gradient.last.withAlpha(150),
                blurRadius: _pressed ? 8 : 16,
                offset: Offset(0, _pressed ? 3 : 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Inner highlight — radial gradient anchored to
              // top-left so the tile reads as raised plastic
              // rather than flat.
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: RadialGradient(
                        center: const Alignment(-0.6, -0.6),
                        radius: 1.1,
                        colors: [
                          Colors.white.withAlpha(70),
                          Colors.white.withAlpha(0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Decorative floating circles.
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(28),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      spec.emoji,
                      style: const TextStyle(fontSize: 30),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spec.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.newsreader(
                            fontSize: 18,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                            height: 1.0,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          spec.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withAlpha(220),
                          ),
                        ),
                      ],
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
