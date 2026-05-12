import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/locale/money.dart';
import '../../../../../core/network/supabase_client.dart';

/// Feature 4 — Gamified Wardrobe Stats.
///
/// Horizontal scroll of colourful metric cards that surface the
/// user's wardrobe achievements. Three cards today:
///
///   * **Closet Value** — soft mock; "amount you'd have spent
///     buying instead of mixing & matching." Drives the
///     gamification beat (savings → reward feedback).
///   * **Items Digitized** — real count from the wardrobe_items
///     table for the calling user.
///   * **Style Streak** — soft mock; days the user has logged an
///     outfit. Will go live when we wire the wardrobe-planner
///     log to a streak counter.
///
/// Tappable: each card routes to the relevant detail surface
/// (`/wardrobe` for the first two, `/wardrobe/calendar` for the
/// streak).
class WardrobeStatsRow extends StatefulWidget {
  const WardrobeStatsRow({super.key});

  @override
  State<WardrobeStatsRow> createState() => _WardrobeStatsRowState();
}

class _WardrobeStatsRowState extends State<WardrobeStatsRow> {
  int? _digitizedCount;
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
      // `count` modifier returns just the row count without
      // hydrating bodies — cheaper than `.select()` then
      // `.length`.
      final rows = await AppSupabase.client
          .from('wardrobe_items')
          .select('id')
          .eq('user_id', uid);
      if (!mounted) return;
      setState(() {
        _digitizedCount = (rows as List).length;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = <_Stat>[
      _Stat(
        emoji: '💰',
        label: 'Closet Value',
        value: Money.formatStatic(45000),
        caption: 'saved by mixing & matching',
        route: '/wardrobe',
        gradient: const [Color(0xFF6B3B00), Color(0xFFB8860B)],
      ),
      _Stat(
        emoji: '👗',
        label: 'Items Digitized',
        value: _loaded ? '${_digitizedCount ?? 0}' : '—',
        caption: 'items in your closet',
        route: '/wardrobe',
        gradient: const [Color(0xFF8E4180), Color(0xFFD96AA0)],
      ),
      _Stat(
        emoji: '🔥',
        label: 'Style Streak',
        value: '5',
        caption: 'days logged in a row',
        route: '/wardrobe/calendar',
        gradient: const [Color(0xFFC03A2B), Color(0xFFFB8C5C)],
      ),
    ];

    return SizedBox(
      height: 138,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _StatCard(stat: stats[i]),
      ),
    );
  }
}

class _Stat {
  const _Stat({
    required this.emoji,
    required this.label,
    required this.value,
    required this.caption,
    required this.route,
    required this.gradient,
  });

  final String emoji;
  final String label;
  final String value;
  final String caption;
  final String route;
  final List<Color> gradient;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(stat.route),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 180,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: stat.gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: stat.gradient.first.withAlpha(140),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -25,
                right: -25,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(35),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stat.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 6),
                  Text(
                    stat.label.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: Colors.white.withAlpha(220),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stat.value,
                    style: GoogleFonts.newsreader(
                      fontSize: 24,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stat.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: Colors.white.withAlpha(225),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
