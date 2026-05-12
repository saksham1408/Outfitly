import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/location/location_service.dart';
import '../../../../../core/network/supabase_client.dart';

/// Mandate 2 — Gemini-style AI Morning Briefing.
///
/// Wide hero card that replaces the static greeting beat.
/// Animated deep-purple → midnight-blue gradient breathes
/// behind a contextual paragraph composed from three live
/// signals:
///
///   1. **Time of day** — drives the greeting verb and weather
///      copy. Adapts to summer/winter via the current month so
///      the "perfect linen weather" line doesn't lie in
///      January.
///   2. **Location** — pulled from [LocationService]; we name
///      the city if we have it.
///   3. **Next tailor visit** — queried from
///      `tailor_appointments`. If a visit is scheduled, it
///      lands in the paragraph with the time slot.
///
/// Below the paragraph: a glowing "Take Action" pill that
/// routes contextually — to the live visit tracker if one
/// exists, otherwise to the AI Stylist screen.
class AiMorningBriefing extends StatefulWidget {
  const AiMorningBriefing({super.key});

  @override
  State<AiMorningBriefing> createState() => _AiMorningBriefingState();
}

class _AiMorningBriefingState extends State<AiMorningBriefing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  String _firstName = '';
  String? _nextVisitId;
  String? _nextVisitTimeLabel;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _hydrate();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    final client = AppSupabase.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loaded = true);
      return;
    }

    try {
      final profile = await client
          .from('profiles')
          .select('full_name')
          .eq('id', uid)
          .maybeSingle();
      final full = (profile?['full_name'] as String?)?.trim() ?? '';
      if (mounted) {
        setState(() {
          _firstName = full.isEmpty ? '' : full.split(' ').first;
        });
      }
    } catch (_) {/* silent */}

    try {
      final row = await client
          .from('tailor_appointments')
          .select('id, scheduled_time, status')
          .eq('user_id', uid)
          .inFilter('status', const [
            'pending',
            'pending_tailor_approval',
            'accepted',
            'en_route',
            'arrived',
          ])
          .order('scheduled_time', ascending: true)
          .limit(1)
          .maybeSingle();
      if (row != null) {
        final ts = DateTime.tryParse(
          row['scheduled_time'] as String? ?? '',
        )?.toLocal();
        if (mounted) {
          setState(() {
            _nextVisitId = row['id'] as String?;
            _nextVisitTimeLabel = ts != null ? _hhmm(ts) : null;
          });
        }
      }
    } catch (_) {/* silent */}

    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _greetingForNow();
    final tempCopy = _weatherCopy();
    final cityLabel = _cityLabel();
    final paragraph = _composeParagraph(
      greeting: greeting,
      cityLabel: cityLabel,
      tempCopy: tempCopy,
    );
    final hasVisit = _nextVisitId != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (context, _) {
          final t = _shimmer.value;
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              // Subtle orbiting gradient — deep purple → midnight
              // blue → magenta — so the card has a slow living
              // backdrop rather than a flat fill.
              gradient: LinearGradient(
                begin: _orbit(t, 0.0),
                end: _orbit(t, 0.5),
                colors: const [
                  Color(0xFF1F0A4A),
                  Color(0xFF3E1A8B),
                  Color(0xFF7A2EBE),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7A2EBE).withAlpha(110),
                  blurRadius: 22,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decorative floating blurs.
                Positioned(
                  top: -30,
                  right: -20,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(40),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  left: -30,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFEC4899).withAlpha(40),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(40),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withAlpha(100),
                              ),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(40),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withAlpha(90),
                              ),
                            ),
                            child: Text(
                              'AI MORNING BRIEFING',
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
                      _loaded
                          ? Text(
                              paragraph,
                              style: GoogleFonts.manrope(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                height: 1.5,
                              ),
                            )
                          : _SkeletonParagraph(),
                      const SizedBox(height: 16),
                      _TakeActionPill(
                        label: hasVisit
                            ? 'Track your tailor'
                            : 'Ask the stylist',
                        onTap: () => context.push(
                          hasVisit
                              ? '/tailor-visit/$_nextVisitId'
                              : '/outfitly-ai',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Copy composition ────────────────────────────────────

  String _composeParagraph({
    required String greeting,
    required String cityLabel,
    required String tempCopy,
  }) {
    final name = _firstName.isEmpty ? '' : ' $_firstName';
    final visit = _nextVisitTimeLabel;

    final intro = '✨ $greeting$name!';
    final weather = '$tempCopy in $cityLabel — '
        '${_weatherSuggestion()}';
    final visitLine = visit != null
        ? ' Tailor Amit is scheduled for $visit for your fitting. '
            'Would you like to review your measurements?'
        : ' Nothing scheduled today — a great moment to plan an outfit '
            'or build a new combo.';

    return '$intro $weather$visitLine';
  }

  String _greetingForNow() {
    final h = DateTime.now().hour;
    if (h >= 4 && h < 11) return 'Good Morning';
    if (h >= 11 && h < 16) return 'Good Afternoon';
    if (h >= 16 && h < 20) return 'Good Evening';
    return 'Good Evening';
  }

  String _weatherCopy() {
    // Soft mock — adapts to month + time bucket so the
    // briefing doesn't claim "perfect linen weather" in
    // January.
    final h = DateTime.now().hour;
    final summer = DateTime.now().month >= 4 &&
        DateTime.now().month <= 9;
    if (summer) {
      if (h < 11) return "It's 28°C this morning";
      if (h < 16) return "It's 32°C today";
      if (h < 20) return "It's 30°C this evening";
      return "It's 26°C tonight";
    }
    if (h < 11) return "It's 16°C this morning";
    if (h < 16) return "It's 22°C today";
    if (h < 20) return "It's 20°C this evening";
    return "It's 14°C tonight";
  }

  String _weatherSuggestion() {
    final summer = DateTime.now().month >= 4 &&
        DateTime.now().month <= 9;
    return summer
        ? 'perfect weather for the breathable linens in your closet.'
        : 'reach for a kurta jacket or a wool-blend bandhgala.';
  }

  String _cityLabel() {
    final loc = LocationService.instance.location.value;
    if (loc != null && loc.city.trim().isNotEmpty) return loc.city.trim();
    return 'your city';
  }

  Alignment _orbit(double t, double phase) {
    final theta = (t + phase) * 2 * math.pi;
    return Alignment(math.cos(theta) * 0.9, math.sin(theta) * 0.9);
  }
}

class _SkeletonParagraph extends StatelessWidget {
  const _SkeletonParagraph();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.only(bottom: i == 2 ? 0 : 6),
          child: Container(
            height: 12,
            width: double.infinity * (i == 2 ? 0.7 : 1.0),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(45),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
      }),
    );
  }
}

class _TakeActionPill extends StatefulWidget {
  const _TakeActionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_TakeActionPill> createState() => _TakeActionPillState();
}

class _TakeActionPillState extends State<_TakeActionPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            // Gradient pill — pink → purple — sitting on the
            // dark briefing card, with a glow that softens on
            // press.
            gradient: const LinearGradient(
              colors: [Color(0xFFEC4899), Color(0xFFA855F7)],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEC4899).withAlpha(_pressed ? 60 : 140),
                blurRadius: _pressed ? 6 : 16,
                offset: Offset(0, _pressed ? 3 : 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _hhmm(DateTime dt) {
  final h = dt.hour;
  final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour12:$minute ${h < 12 ? 'AM' : 'PM'}';
}
