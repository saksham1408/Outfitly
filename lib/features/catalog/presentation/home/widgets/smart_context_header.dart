import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/location/location_service.dart';
import '../../../../../core/network/supabase_client.dart';

/// Feature 1 — Smart Context Header.
///
/// Replaces the old plain hero strip with a vibrant,
/// time-of-day-aware gradient + a personalised greeting + a
/// dynamic weather/location subtitle.
///
/// The gradient palette rotates across four windows so the
/// home screen "breathes" with the day:
///   * 04:00–11:00 — dawn (rose + peach + soft gold)
///   * 11:00–16:00 — bright noon (sky + mint + warm wheat)
///   * 16:00–19:30 — dusk (terracotta + amber + plum)
///   * 19:30–04:00 — night (indigo + deep purple + starlight)
///
/// The greeting pulls the user's first name from `profiles`; the
/// weather sub-line is a soft mock today (location is real —
/// LocationService — temperature is a friendly placeholder
/// driven by season + time bucket so it doesn't lie about
/// "perfect cotton weather" in January).
class SmartContextHeader extends StatefulWidget {
  const SmartContextHeader({super.key});

  @override
  State<SmartContextHeader> createState() => _SmartContextHeaderState();
}

class _SmartContextHeaderState extends State<SmartContextHeader> {
  String _firstName = '';
  bool _loadedName = false;

  @override
  void initState() {
    super.initState();
    _hydrateName();
  }

  Future<void> _hydrateName() async {
    final uid = AppSupabase.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loadedName = true);
      return;
    }
    try {
      final row = await AppSupabase.client
          .from('profiles')
          .select('full_name')
          .eq('id', uid)
          .maybeSingle();
      if (!mounted) return;
      final full = (row?['full_name'] as String?)?.trim() ?? '';
      setState(() {
        _firstName = full.isEmpty ? '' : full.split(' ').first;
        _loadedName = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loadedName = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForNow();
    final greeting = _greeting(palette.bucket);
    final cityLabel = _cityLabel();
    final weather = _weatherCopy(palette.bucket);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.colors,
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: palette.colors.first.withAlpha(140),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative blurred circles — same depth trick the
          // collection cards + atelier story use.
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(35),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(20),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Eyebrow with the time-of-day label + sparkle.
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(50),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          palette.icon,
                          size: 11,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          palette.label,
                          style: GoogleFonts.manrope(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _loadedName
                    ? '$greeting${_firstName.isEmpty ? '' : ' $_firstName'}!  ✨'
                    : greeting,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.newsreader(
                  fontSize: 24,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                  height: 1.05,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Looking sharp today.',
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withAlpha(225),
                ),
              ),
              const SizedBox(height: 14),
              // Weather + location strip.
              _WeatherStrip(
                cityLabel: cityLabel,
                weatherEmoji: palette.weatherEmoji,
                weatherCopy: weather,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Time-of-day palette ─────────────────────────────────

  _Palette _paletteForNow() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) {
      return const _Palette(
        bucket: _DayBucket.dawn,
        label: 'GOOD MORNING',
        icon: Icons.wb_twilight_rounded,
        weatherEmoji: '☀️',
        colors: [
          Color(0xFFFF8E72),
          Color(0xFFFFB48F),
          Color(0xFFFFD58F),
        ],
      );
    }
    if (hour >= 11 && hour < 16) {
      return const _Palette(
        bucket: _DayBucket.noon,
        label: 'GOOD AFTERNOON',
        icon: Icons.wb_sunny_rounded,
        weatherEmoji: '☀️',
        colors: [
          Color(0xFF3AA0E0),
          Color(0xFF7EC9B5),
          Color(0xFFE8C97A),
        ],
      );
    }
    if (hour >= 16 && hour < 20) {
      return const _Palette(
        bucket: _DayBucket.dusk,
        label: 'GOOD EVENING',
        icon: Icons.wb_twilight_rounded,
        weatherEmoji: '🌅',
        colors: [
          Color(0xFFD45D43),
          Color(0xFFE38A4A),
          Color(0xFF8E4180),
        ],
      );
    }
    return const _Palette(
      bucket: _DayBucket.night,
      label: 'GOOD EVENING',
      icon: Icons.nights_stay_rounded,
      weatherEmoji: '🌙',
      colors: [
        Color(0xFF1F1E4F),
        Color(0xFF3B1A60),
        Color(0xFF8E4180),
      ],
    );
  }

  String _greeting(_DayBucket bucket) {
    switch (bucket) {
      case _DayBucket.dawn:
        return 'Good morning,';
      case _DayBucket.noon:
        return 'Hello,';
      case _DayBucket.dusk:
        return 'Good evening,';
      case _DayBucket.night:
        return 'Hi there,';
    }
  }

  String _cityLabel() {
    final loc = LocationService.instance.location.value;
    if (loc != null && loc.city.trim().isNotEmpty) return loc.city.trim();
    return 'India';
  }

  /// Mocked weather copy that adapts to the time bucket. Real
  /// weather wiring is a backlog item — we use a friendly
  /// season-aware placeholder so the home doesn't look fake.
  String _weatherCopy(_DayBucket bucket) {
    final month = DateTime.now().month;
    final summer = month >= 4 && month <= 9;
    switch (bucket) {
      case _DayBucket.dawn:
        return summer
            ? '28°C · Perfect for light cottons.'
            : '18°C · Throw on a kurta jacket.';
      case _DayBucket.noon:
        return summer
            ? '32°C · Reach for linen.'
            : '22°C · Crisp cotton-silk weather.';
      case _DayBucket.dusk:
        return summer
            ? '30°C · Cool linens for the evening.'
            : '20°C · A shawl wouldn\'t hurt.';
      case _DayBucket.night:
        return summer
            ? '26°C · Easy silk · easy mood.'
            : '15°C · Velvet o\'clock.';
    }
  }
}

class _WeatherStrip extends StatelessWidget {
  const _WeatherStrip({
    required this.cityLabel,
    required this.weatherEmoji,
    required this.weatherCopy,
  });

  final String cityLabel;
  final String weatherEmoji;
  final String weatherCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(80)),
      ),
      child: Row(
        children: [
          Text(weatherEmoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$weatherCopy  ·  $cityLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _DayBucket { dawn, noon, dusk, night }

class _Palette {
  const _Palette({
    required this.bucket,
    required this.label,
    required this.icon,
    required this.weatherEmoji,
    required this.colors,
  });

  final _DayBucket bucket;
  final String label;
  final IconData icon;
  final String weatherEmoji;
  final List<Color> colors;
}
