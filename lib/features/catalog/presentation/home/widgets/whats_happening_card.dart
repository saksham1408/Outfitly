import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/network/supabase_client.dart';
import '../../../../../core/theme/theme.dart';

/// "What's Happening" hero card — replaces the old passive
/// "Craft Your Signature Look" banner that sat at the top of
/// the home feed without doing any work.
///
/// Looks across three live activity streams on each cold launch:
///
///   1. **`tailor_appointments`** — the customer has an
///      in-flight home-visit (pending / accepted / en_route /
///      arrived). Wins highest priority because a tailor is
///      actively coming over.
///   2. **`custom_stitch_orders`** — Stitch My Fabric pickup
///      that isn't delivered yet.
///   3. **`orders`** — most recently-placed bespoke order that
///      isn't `delivered`.
///
/// Whichever fires first (by priority + recency) drives the
/// card. Renders the activity's headline + a status pill +
/// a deep-link "Track" CTA. If nothing is in flight, the card
/// collapses to zero height so the home reads calm.
class WhatsHappeningCard extends StatefulWidget {
  const WhatsHappeningCard({super.key});

  @override
  State<WhatsHappeningCard> createState() => _WhatsHappeningCardState();
}

class _WhatsHappeningCardState extends State<WhatsHappeningCard> {
  late Future<_ActivityPreview?> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadActivity();
  }

  /// Read the three feeds in priority order and return the first
  /// match (or null if nothing's active). Each leg fails soft —
  /// a missing migration on a fresh project shouldn't crash the
  /// home screen, it should just hide the card.
  Future<_ActivityPreview?> _loadActivity() async {
    final user = AppSupabase.client.auth.currentUser;
    if (user == null) return null;

    // 1. Tailor visit — highest priority, "someone's coming over".
    try {
      final row = await AppSupabase.client
          .from('tailor_appointments')
          .select('id, status, scheduled_time')
          .eq('user_id', user.id)
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
      if (row != null) {
        return _ActivityPreview(
          kind: _ActivityKind.tailorVisit,
          status: (row['status'] as String?) ?? 'pending',
          headline: 'Your tailor visit',
          route: '/tailor-visit/${row['id']}',
        );
      }
    } catch (_) {/* swallow */}

    // 2. Stitch My Fabric pickup.
    try {
      final row = await AppSupabase.client
          .from('custom_stitch_orders')
          .select('id, status, garment_type')
          .eq('user_id', user.id)
          .neq('status', 'delivered')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row != null) {
        final garment = (row['garment_type'] as String?) ?? 'Pickup';
        return _ActivityPreview(
          kind: _ActivityKind.fabricPickup,
          status: (row['status'] as String?) ?? 'pending_pickup',
          headline: '$garment pickup',
          route: '/custom-stitching/dashboard',
        );
      }
    } catch (_) {/* swallow */}

    // 3. Latest in-flight bespoke order.
    try {
      final row = await AppSupabase.client
          .from('orders')
          .select('id, status, product_name, design_choices')
          .eq('user_id', user.id)
          .neq('status', 'delivered')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row != null) {
        final name = (row['product_name'] as String?) ?? 'Your order';
        // If it's part of a combo set, deep-link to the combo
        // tracker (richer view); otherwise the standard
        // /orders list.
        final design = row['design_choices'];
        String route = '/orders';
        if (design is Map<String, dynamic>) {
          final setId = design['combo_set_id'] as String?;
          if (setId != null && setId.isNotEmpty) {
            route = '/combos/tracking/$setId';
          }
        }
        return _ActivityPreview(
          kind: _ActivityKind.order,
          status: (row['status'] as String?) ?? 'order_placed',
          headline: name,
          route: route,
        );
      }
    } catch (_) {/* swallow */}

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ActivityPreview?>(
      future: _future,
      builder: (context, snap) {
        // While loading, reserve no space — the home feed
        // shouldn't jump when we finally resolve. The card
        // appears smoothly on data, or stays hidden on null.
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final preview = snap.data;
        if (preview == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _PreviewTile(preview: preview),
        );
      },
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.preview});

  final _ActivityPreview preview;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(preview.kind);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(preview.route),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette.gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.gradient.first.withAlpha(80),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative blur — same trick used by the
              // collection cards + atelier story for visual
              // depth without an asset.
              Positioned(
                top: -40,
                right: -40,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(30),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(40),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            palette.eyebrow,
                            style: GoogleFonts.manrope(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      preview.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.newsreader(
                        fontSize: 22,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _humaniseStatus(preview.kind, preview.status),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withAlpha(225),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _TrackPill(label: palette.cta),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({List<Color> gradient, String eyebrow, String cta}) _paletteFor(
      _ActivityKind kind) {
    switch (kind) {
      case _ActivityKind.tailorVisit:
        return (
          gradient: const [Color(0xFF17362E), Color(0xFF3A6657)],
          eyebrow: 'TAILOR VISIT',
          cta: 'Track visit',
        );
      case _ActivityKind.fabricPickup:
        return (
          gradient: const [Color(0xFF6B3B00), Color(0xFFB8860B)],
          eyebrow: 'FABRIC PICKUP',
          cta: 'See pickup',
        );
      case _ActivityKind.order:
        return (
          gradient: const [Color(0xFF2A1A4F), Color(0xFF6B4A8F)],
          eyebrow: 'YOUR ORDER',
          cta: 'Track order',
        );
    }
  }
}

class _TrackPill extends StatelessWidget {
  const _TrackPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11.5,
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
    );
  }
}

// ────────────────────────────────────────────────────────────
// Internal model
// ────────────────────────────────────────────────────────────

enum _ActivityKind { tailorVisit, fabricPickup, order }

class _ActivityPreview {
  const _ActivityPreview({
    required this.kind,
    required this.status,
    required this.headline,
    required this.route,
  });

  final _ActivityKind kind;
  final String status;
  final String headline;
  final String route;
}

String _humaniseStatus(_ActivityKind kind, String dbStatus) {
  // Keep the copy SHORT — this lives on a hero card and the
  // headline above it already carries the noun.
  switch (dbStatus) {
    case 'pending':
    case 'pending_tailor_approval':
      return 'Waiting for a tailor to accept';
    case 'accepted':
      return 'Tailor accepted — preparing to leave';
    case 'en_route':
      return 'Tailor is on the way';
    case 'arrived':
      return 'Tailor is at your door';
    case 'pending_pickup':
      return 'Pickup scheduled';
    case 'fabric_collected':
      return 'Fabric collected by the atelier';
    case 'stitching':
      return 'In the stitching room';
    case 'ready_for_delivery':
      return 'Ready — out for delivery soon';
    case 'order_placed':
      return 'Order placed';
    case 'fabric_sourcing':
      return 'Sourcing fabric';
    case 'cutting':
      return 'In the cutting room';
    case 'embroidery_finishing':
      return 'Embroidery + finishing';
    case 'quality_check':
      return 'Quality check';
    case 'out_for_delivery':
      return 'Out for delivery';
    default:
      return 'In progress';
  }
}
