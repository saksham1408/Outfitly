import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/locale/money.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../models/family_member.dart';

/// Post-checkout tracker for orders placed via the Family /
/// Couple Combo flow.
///
/// Two layouts share this screen, picked from the set of roles
/// present in the placed orders:
///
///   * **Couple** — the order set contains exactly `male` and
///     `female`. Renders two cards side-by-side (or stacked on
///     narrow screens), one tracker per partner. Each timeline
///     advances independently so a customer can see, e.g.,
///     "his kurta is at Stitching, her saree is at Quality
///     Check".
///   * **Family** — anything else (parents + siblings + kids,
///     etc.). Renders a single COMBINED card that lists every
///     family member's piece together under one shared timeline.
///     A family is one bespoke job from the atelier's view, so
///     one tracker accurately reflects how it moves.
///
/// Powered by `orders.design_choices->>combo_set_id` (stamped at
/// checkout). RLS scopes the query to the calling customer, so
/// the screen safely shows only their own combo set.
class ComboTrackingScreen extends StatefulWidget {
  const ComboTrackingScreen({super.key, required this.comboSetId});

  final String comboSetId;

  @override
  State<ComboTrackingScreen> createState() => _ComboTrackingScreenState();
}

class _ComboTrackingScreenState extends State<ComboTrackingScreen> {
  late Future<List<_ComboOrderRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_ComboOrderRow>> _load() async {
    try {
      final rows = await AppSupabase.client
          .from('orders')
          .select()
          .filter('design_choices->>combo_set_id', 'eq', widget.comboSetId)
          .order('created_at', ascending: true);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(_ComboOrderRow.fromMap)
          .toList(growable: false);
    } catch (e) {
      debugPrint('ComboTrackingScreen.load failed — $e');
      return const [];
    }
  }

  Future<void> _refresh() async {
    final fresh = await _load();
    if (!mounted) return;
    setState(() => _future = Future.value(fresh));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          'Your Combo',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: FutureBuilder<List<_ComboOrderRow>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = snapshot.data ?? const [];
            if (orders.isEmpty) {
              return _EmptyState(comboSetId: widget.comboSetId);
            }

            final isCouple = _isCoupleSet(orders);

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _HeroHeader(
                    orders: orders,
                    isCouple: isCouple,
                  ),
                  const SizedBox(height: 20),
                  if (isCouple)
                    _CoupleTrackers(orders: orders)
                  else
                    _FamilyTracker(orders: orders),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Couple set = exactly the male + female roles present (no
  /// children, no grandparents). Anything else is treated as
  /// family-shaped. Order count doesn't matter — what matters
  /// is the role mix.
  bool _isCoupleSet(List<_ComboOrderRow> orders) {
    final roles = orders.map((o) => o.role).toSet();
    return roles.length == 2 &&
        roles.contains(FamilyRole.male) &&
        roles.contains(FamilyRole.female);
  }
}

// ────────────────────────────────────────────────────────────
// Hero header
// ────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.orders, required this.isCouple});

  final List<_ComboOrderRow> orders;
  final bool isCouple;

  @override
  Widget build(BuildContext context) {
    final total = orders.fold<double>(0, (sum, o) => sum + o.totalPrice);
    final eta = orders
        .map((o) => o.estimatedDelivery)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (acc, d) => acc == null || d.isAfter(acc) ? d : acc);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF17362E),
            Color(0xFF2F5249),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isCouple ? 'COUPLE COMBO' : 'FAMILY COMBO',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isCouple
                ? 'Two looks, two timelines'
                : 'One family. One coordinated drop.',
            style: GoogleFonts.newsreader(
              fontSize: 24,
              fontStyle: FontStyle.italic,
              color: Colors.white,
              height: 1.05,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _stat('${orders.length}', 'PIECES'),
              const SizedBox(width: 20),
              _stat(Money.formatStatic(total), 'TOTAL'),
              if (eta != null) ...[
                const SizedBox(width: 20),
                _stat(_formatDate(eta), 'EST. ARRIVAL'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Colors.white.withAlpha(180),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

// ────────────────────────────────────────────────────────────
// Couple — two trackers, one per partner
// ────────────────────────────────────────────────────────────

class _CoupleTrackers extends StatelessWidget {
  const _CoupleTrackers({required this.orders});

  final List<_ComboOrderRow> orders;

  @override
  Widget build(BuildContext context) {
    final male = orders.where((o) => o.role == FamilyRole.male).toList();
    final female =
        orders.where((o) => o.role == FamilyRole.female).toList();

    return Column(
      children: [
        _PartnerTracker(
          partnerLabel: 'Him',
          icon: Icons.man_rounded,
          accentColor: const Color(0xFF1F3A57),
          orders: male,
        ),
        const SizedBox(height: 14),
        _PartnerTracker(
          partnerLabel: 'Her',
          icon: Icons.woman_rounded,
          accentColor: const Color(0xFF7A2E1F),
          orders: female,
        ),
      ],
    );
  }
}

class _PartnerTracker extends StatelessWidget {
  const _PartnerTracker({
    required this.partnerLabel,
    required this.icon,
    required this.accentColor,
    required this.orders,
  });

  final String partnerLabel;
  final IconData icon;
  final Color accentColor;
  final List<_ComboOrderRow> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return const SizedBox.shrink();
    // For the couple flow each partner is one role with one
    // piece — use the worst-status (earliest in pipeline) so
    // the timeline never overshoots reality.
    final aggregateStatus = _earliestStatus(orders);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withAlpha(60)),
      ),
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
                  color: accentColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partnerLabel,
                      style: GoogleFonts.newsreader(
                        fontSize: 22,
                        fontStyle: FontStyle.italic,
                        color: AppColors.primary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      orders.map((o) => o.productName).join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ProgressStrip(status: aggregateStatus, accent: accentColor),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Family — single combined tracker
// ────────────────────────────────────────────────────────────

class _FamilyTracker extends StatelessWidget {
  const _FamilyTracker({required this.orders});

  final List<_ComboOrderRow> orders;

  @override
  Widget build(BuildContext context) {
    final aggregate = _earliestStatus(orders);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHO\'S GETTING WHAT',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 10),
          for (final order in orders) ...[
            _FamilyMemberRow(order: order),
            if (order != orders.last)
              Divider(
                color: AppColors.primary.withAlpha(15),
                height: 16,
              ),
          ],
          const SizedBox(height: 16),
          Text(
            'COMBINED PROGRESS',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          _ProgressStrip(status: aggregate, accent: AppColors.primary),
          const SizedBox(height: 10),
          Text(
            'The atelier handles a family combo as one coordinated job — every piece moves through the pipeline together so the looks land at your door at the same time.',
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: AppColors.textTertiary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyMemberRow extends StatelessWidget {
  const _FamilyMemberRow({required this.order});

  final _ComboOrderRow order;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _iconFor(order.role),
            size: 20,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.role.label,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                order.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        Text(
          Money.formatStatic(order.totalPrice),
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }

  IconData _iconFor(FamilyRole role) {
    switch (role) {
      case FamilyRole.grandfather:
        return Icons.elderly;
      case FamilyRole.grandmother:
        return Icons.elderly_woman;
      case FamilyRole.father:
      case FamilyRole.male:
        return Icons.man_rounded;
      case FamilyRole.mother:
      case FamilyRole.female:
        return Icons.woman_rounded;
      case FamilyRole.son:
        return Icons.boy_rounded;
      case FamilyRole.daughter:
        return Icons.girl_rounded;
    }
  }
}

// ────────────────────────────────────────────────────────────
// Shared progress strip — eight-step pipeline
// ────────────────────────────────────────────────────────────

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.status, required this.accent});

  final String status;
  final Color accent;

  static const _steps = <(String key, String label)>[
    ('order_placed', 'Placed'),
    ('fabric_sourcing', 'Fabric'),
    ('cutting', 'Cut'),
    ('stitching', 'Stitch'),
    ('embroidery_finishing', 'Embroidery'),
    ('quality_check', 'QC'),
    ('out_for_delivery', 'Dispatch'),
    ('delivered', 'Delivered'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIdx = _steps
        .indexWhere((s) => s.$1 == status)
        .clamp(0, _steps.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(_steps.length * 2 - 1, (i) {
            if (i.isEven) {
              final stepIdx = i ~/ 2;
              final reached = stepIdx <= currentIdx;
              return _Node(reached: reached, accent: accent);
            } else {
              final connectorIdx = i ~/ 2;
              final filled = connectorIdx < currentIdx;
              return Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: filled
                      ? accent
                      : AppColors.primary.withAlpha(25),
                ),
              );
            }
          }),
        ),
        const SizedBox(height: 8),
        Text(
          _steps[currentIdx].$2.toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: accent,
          ),
        ),
      ],
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.reached, required this.accent});

  final bool reached;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: reached ? accent : AppColors.background,
        border: Border.all(
          color: reached ? accent : AppColors.primary.withAlpha(35),
          width: 2,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Empty state
// ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.comboSetId});

  final String comboSetId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 56,
              color: AppColors.primary.withAlpha(80),
            ),
            const SizedBox(height: 16),
            Text(
              'Looking for your combo…',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'If you just placed the order, the rows can take a moment to appear. Pull down to refresh.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => context.go('/orders'),
              child: Text(
                'OPEN ORDER HISTORY',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Internal row model + helpers
// ────────────────────────────────────────────────────────────

/// Thin row model — only the fields the tracker actually needs.
/// Built from the `orders` table query result.
class _ComboOrderRow {
  const _ComboOrderRow({
    required this.id,
    required this.productName,
    required this.role,
    required this.status,
    required this.totalPrice,
    this.estimatedDelivery,
  });

  final String id;
  final String productName;
  final FamilyRole role;
  final String status;
  final double totalPrice;
  final DateTime? estimatedDelivery;

  factory _ComboOrderRow.fromMap(Map<String, dynamic> map) {
    final design = map['design_choices'] is Map<String, dynamic>
        ? map['design_choices'] as Map<String, dynamic>
        : <String, dynamic>{};
    final roleName = (design['role'] as String?)?.trim() ?? '';
    return _ComboOrderRow(
      id: map['id'] as String,
      productName: (map['product_name'] as String?) ?? '—',
      role: _roleFromName(roleName),
      status: (map['status'] as String?) ?? 'order_placed',
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0,
      estimatedDelivery: DateTime.tryParse(
        (map['estimated_delivery'] as String?) ?? '',
      ),
    );
  }
}

FamilyRole _roleFromName(String name) {
  switch (name) {
    case 'grandfather':
      return FamilyRole.grandfather;
    case 'grandmother':
      return FamilyRole.grandmother;
    case 'father':
      return FamilyRole.father;
    case 'mother':
      return FamilyRole.mother;
    case 'son':
      return FamilyRole.son;
    case 'daughter':
      return FamilyRole.daughter;
    case 'male':
      return FamilyRole.male;
    case 'female':
      return FamilyRole.female;
    default:
      // Fallback — non-combo or malformed rows shouldn't reach
      // this screen, but if they do they get a neutral bucket.
      return FamilyRole.male;
  }
}

/// Pick the earliest-pipeline status across the row set so the
/// aggregate progress strip never overshoots what the slowest
/// item is doing.
String _earliestStatus(List<_ComboOrderRow> rows) {
  const order = [
    'order_placed',
    'fabric_sourcing',
    'cutting',
    'stitching',
    'embroidery_finishing',
    'quality_check',
    'out_for_delivery',
    'delivered',
  ];
  var minIdx = order.length - 1;
  for (final r in rows) {
    final idx = order.indexOf(r.status);
    if (idx >= 0 && idx < minIdx) minIdx = idx;
  }
  return order[minIdx];
}
