import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/locale/money.dart';
import '../../../../../core/network/supabase_client.dart';

/// Mandate 1 — Glassmorphic Stats Deck.
///
/// A horizontally-scrollable strip of four metric cards. Each
/// card is a dark, semi-transparent surface clipped by a
/// [BackdropFilter] so it blurs whatever sits behind it on the
/// scaffold. Decorative gradient anchors a top "glow" border,
/// and a [ShaderMask]-driven gradient icon floats in the
/// top-right of every card.
///
/// Four metrics today:
///   1. Items Digitized  — live count from `wardrobe_items`
///   2. Closet Value     — mock ₹45,000 (the "savings"
///                          gamification beat)
///   3. Style Streak     — mock 5 days
///   4. Active Bookings  — live count from in-flight
///                          `tailor_appointments`
class GlassStatsDeck extends StatefulWidget {
  const GlassStatsDeck({super.key});

  @override
  State<GlassStatsDeck> createState() => _GlassStatsDeckState();
}

class _GlassStatsDeckState extends State<GlassStatsDeck> {
  int? _digitized;
  int? _activeBookings;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final uid = AppSupabase.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    try {
      final wardrobe = await AppSupabase.client
          .from('wardrobe_items')
          .select('id')
          .eq('user_id', uid);
      final visits = await AppSupabase.client
          .from('tailor_appointments')
          .select('id')
          .eq('user_id', uid)
          .inFilter('status', const [
            'pending',
            'pending_tailor_approval',
            'accepted',
            'en_route',
            'arrived',
          ]);
      if (!mounted) return;
      setState(() {
        _digitized = (wardrobe as List).length;
        _activeBookings = (visits as List).length;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = <_StatSpec>[
      _StatSpec(
        eyebrow: 'CLOSET',
        title: 'Items Digitized',
        value: _loaded ? '${_digitized ?? 0}' : '—',
        suffix: 'pieces',
        icon: Icons.checkroom_rounded,
        accentGradient: const [Color(0xFFEC4899), Color(0xFFA855F7)],
        route: '/wardrobe',
      ),
      _StatSpec(
        eyebrow: 'SAVINGS',
        title: 'Closet Value',
        value: Money.formatStatic(45000),
        suffix: 'mix & matched',
        icon: Icons.diamond_outlined,
        accentGradient: const [Color(0xFFFBBF24), Color(0xFFF97316)],
        route: '/wardrobe',
      ),
      _StatSpec(
        eyebrow: 'HABIT',
        title: 'Style Streak',
        value: '5',
        suffix: 'days logged',
        icon: Icons.local_fire_department_rounded,
        accentGradient: const [Color(0xFFF87171), Color(0xFFC026D3)],
        route: '/wardrobe/calendar',
      ),
      _StatSpec(
        eyebrow: 'LIVE',
        title: 'Active Bookings',
        value: _loaded ? '${_activeBookings ?? 0}' : '—',
        suffix: 'in flight',
        icon: Icons.local_shipping_rounded,
        accentGradient: const [Color(0xFF22D3EE), Color(0xFF818CF8)],
        route: '/orders',
      ),
    ];

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _GlassStatCard(spec: cards[i]),
      ),
    );
  }
}

class _StatSpec {
  const _StatSpec({
    required this.eyebrow,
    required this.title,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.accentGradient,
    required this.route,
  });

  final String eyebrow;
  final String title;
  final String value;
  final String suffix;
  final IconData icon;
  final List<Color> accentGradient;
  final String route;
}

class _GlassStatCard extends StatelessWidget {
  const _GlassStatCard({required this.spec});

  final _StatSpec spec;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(spec.route),
          borderRadius: BorderRadius.circular(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  // Premium dark glass — semi-transparent black
                  // with a subtle inner gradient so the surface
                  // doesn't look like a flat tinted panel.
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withAlpha(230),
                      Colors.black.withAlpha(200),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  // Soft 1px top-border glow in the accent
                  // gradient — gives the card its "lit edge".
                  border: Border.all(
                    color: spec.accentGradient.first.withAlpha(80),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: spec.accentGradient.first.withAlpha(40),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Top-right floating gradient icon — uses
                    // ShaderMask to apply the accent gradient
                    // to the icon itself rather than a flat
                    // colour.
                    Positioned(
                      top: 10,
                      right: 10,
                      child: ShaderMask(
                        shaderCallback: (rect) => LinearGradient(
                          colors: spec.accentGradient,
                        ).createShader(rect),
                        child: Icon(
                          spec.icon,
                          size: 26,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Soft glow halo behind the icon for the
                    // "floating 3D" feel.
                    Positioned(
                      top: -14,
                      right: -14,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: spec.accentGradient.first.withAlpha(45),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Spacer(),
                          // Eyebrow.
                          ShaderMask(
                            shaderCallback: (rect) => LinearGradient(
                              colors: spec.accentGradient,
                            ).createShader(rect),
                            child: Text(
                              spec.eyebrow,
                              style: GoogleFonts.manrope(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Big number.
                          Text(
                            spec.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.newsreader(
                              fontSize: 24,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.0,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Subtitle / caption.
                          Text(
                            spec.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            spec.suffix,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              color: Colors.white.withAlpha(160),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
