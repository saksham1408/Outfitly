import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/network/supabase_client.dart';

/// Feature 5 — Live Activity / Tracking Banner.
///
/// Sits at the top of the scrollable area and ONLY appears when
/// the calling user has an in-flight tailor visit
/// (status ∈ {pending, accepted, en_route, arrived}) or a borrow
/// request that needs attention. High-contrast dark card with a
/// pulsing green indicator so it reads as live state — same
/// "ride is on its way" beat ride-hailing apps use.
///
/// Tap routes to the relevant tracker.
class LiveActivityBanner extends StatefulWidget {
  const LiveActivityBanner({super.key});

  @override
  State<LiveActivityBanner> createState() => _LiveActivityBannerState();
}

class _LiveActivityBannerState extends State<LiveActivityBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Future<_LiveActivity?>? _future;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _future = _load();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Reads `tailor_appointments` for any in-flight visit. We
  /// could expand this to borrow_requests / custom_stitch_orders
  /// in a single union later — for v1 the tailor flow is the
  /// loudest "something's happening right now" surface.
  Future<_LiveActivity?> _load() async {
    final uid = AppSupabase.client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await AppSupabase.client
          .from('tailor_appointments')
          .select('id, status, scheduled_time')
          .eq('user_id', uid)
          .inFilter('status', const [
            'pending',
            'pending_tailor_approval',
            'accepted',
            'en_route',
            'arrived',
          ])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return _LiveActivity(
        id: row['id'] as String,
        status: (row['status'] as String?) ?? 'pending',
        scheduledTime:
            DateTime.tryParse(row['scheduled_time'] as String? ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LiveActivity?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final activity = snap.data;
        if (activity == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/tailor-visit/${activity.id}'),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding:
                    const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1430),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF21D07A).withAlpha(60),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF21D07A).withAlpha(60),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Pulsing green dot — the "alive" tell.
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) {
                        return SizedBox(
                          width: 24,
                          height: 24,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 24 * _pulse.value + 8,
                                height: 24 * _pulse.value + 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF21D07A)
                                      .withAlpha(
                                    (60 * (1 - _pulse.value))
                                        .toInt(),
                                  ),
                                ),
                              ),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF21D07A),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LIVE · TAILOR VISIT',
                            style: GoogleFonts.manrope(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                              color: const Color(0xFF21D07A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _headlineFor(activity),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _headlineFor(_LiveActivity a) {
    final time = a.scheduledTime;
    final timePhrase = time == null
        ? ''
        : ' at ${_hhmm(time.toLocal())}';
    switch (a.status) {
      case 'en_route':
        return '🚗 Your tailor is on the way$timePhrase.';
      case 'arrived':
        return '📍 Your tailor is at your door.';
      case 'accepted':
        return '🧵 Tailor accepted — heading over$timePhrase.';
      case 'pending_tailor_approval':
        return '⏳ Waiting for the tailor you picked to confirm.';
      case 'pending':
      default:
        return '⏳ Finding a tailor near you$timePhrase.';
    }
  }
}

class _LiveActivity {
  const _LiveActivity({
    required this.id,
    required this.status,
    required this.scheduledTime,
  });

  final String id;
  final String status;
  final DateTime? scheduledTime;
}

String _hhmm(DateTime dt) {
  final h = dt.hour;
  final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour12:$minute ${h < 12 ? 'AM' : 'PM'}';
}
