import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../../measurements/data/tailor_appointment_service.dart';
import '../../measurements/domain/tailor_visit.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../widgets/order_card.dart';

/// Top-level "My Orders" tab on the customer app.
///
/// Used to be a single list of garment orders. After we wired up the
/// home-tailor-visit dispatch we ended up with two parallel "things
/// in flight" the customer cares about:
///
///   1. Garment orders — bespoke pieces being made by the atelier.
///      Status driven by Directus admin (`pending_admin_approval` →
///      `stitching` → `out_for_delivery` → `delivered`).
///   2. Tailor visit appointments — Partner-driven home visits for
///      measurements. Status driven by the Partner app (`pending` →
///      `accepted` → `en_route` → `arrived` → `completed`).
///
/// Stuffing both into one list confused the model — they have totally
/// different lifecycles, statuses, and detail screens. So we split
/// them into two tabs that share the same hero header. The detail
/// screen for each is unchanged (`/tracking/<id>` and
/// `/tailor-visit/<id>`), so this is a pure presentation refactor.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Orders',
                    style: GoogleFonts.newsreader(
                      fontSize: 28,
                      fontStyle: FontStyle.italic,
                      color: AppColors.primary,
                    ),
                  ),
                  Container(
                    height: 2,
                    width: 48,
                    margin: const EdgeInsets.only(top: 4),
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Tab bar ──
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textTertiary,
              indicatorColor: AppColors.accent,
              indicatorWeight: 2.5,
              labelStyle: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
              unselectedLabelStyle: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
              tabs: const [
                Tab(text: 'Orders'),
                Tab(text: 'Tailor Visits'),
              ],
            ),

            // ── Tab views ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _OrdersTab(),
                  _TailorVisitsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Tab 1 — Garment orders (the original OrdersScreen body)
// ────────────────────────────────────────────────────────────
class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab>
    with AutomaticKeepAliveClientMixin {
  final _orderService = OrderService();
  List<OrderModel> _orders = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final orders = await _orderService.getOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createDemoOrder() async {
    final order = await _orderService.createDemoOrder();
    if (order != null) _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orders.isEmpty) {
      return _emptyState();
    }
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final order = _orders[index];
          return OrderCard(
            order: order,
            onTap: () => context.push('/tracking/${order.id}'),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: AppColors.textTertiary.withAlpha(60),
          ),
          const SizedBox(height: 16),
          Text(
            'No orders yet',
            style: GoogleFonts.newsreader(
              fontSize: 20,
              fontStyle: FontStyle.italic,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your bespoke creations will appear here',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _createDemoOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Create Demo Order',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Tab 2 — Tailor visits (live Realtime feed)
// ────────────────────────────────────────────────────────────
class _TailorVisitsTab extends StatefulWidget {
  const _TailorVisitsTab();

  @override
  State<_TailorVisitsTab> createState() => _TailorVisitsTabState();
}

class _TailorVisitsTabState extends State<_TailorVisitsTab>
    with AutomaticKeepAliveClientMixin {
  final _service = TailorAppointmentService();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<TailorVisit>>(
      stream: _service.myVisits(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorState(snapshot.error.toString());
        }
        final visits = snapshot.data ?? const <TailorVisit>[];
        if (visits.isEmpty) {
          return _emptyState();
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: visits.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (_, index) => _TailorVisitCard(visit: visits[index]),
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.home_repair_service_outlined,
              size: 56,
              color: AppColors.textTertiary.withAlpha(60),
            ),
            const SizedBox(height: 16),
            Text(
              'No tailor visits yet',
              style: GoogleFonts.newsreader(
                fontSize: 20,
                fontStyle: FontStyle.italic,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you book a home tailor visit, it will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load your tailor visits.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact list-card for a single tailor appointment. Tapping deep-
/// links into the existing live tracker (`/tailor-visit/<id>`), which
/// is the same screen the customer reaches from the order success
/// page — no behavioural change beyond a new entry point.
class _TailorVisitCard extends StatelessWidget {
  const _TailorVisitCard({required this.visit});

  final TailorVisit visit;

  @override
  Widget build(BuildContext context) {
    final pillColor = _pillColor(visit.status);
    return GestureDetector(
      onTap: () => context.push('/tailor-visit/${visit.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withAlpha(60)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + title + status pill
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.home_repair_service_rounded,
                    size: 22,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Home Tailor Visit',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatScheduled(visit.scheduledTime),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: pillColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    visit.status.label.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: pillColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Address line + chevron
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    visit.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Track',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Five-state colour map for the status pill. Mirrors the status
  /// hero copy on the detail screen so the list-row pill and the
  /// detail-page pill always agree visually.
  Color _pillColor(TailorVisitStatus status) {
    switch (status) {
      case TailorVisitStatus.pending:
        return AppColors.primary;
      case TailorVisitStatus.accepted:
      case TailorVisitStatus.enRoute:
      case TailorVisitStatus.arrived:
        return AppColors.accent;
      case TailorVisitStatus.completed:
        return AppColors.accent;
      case TailorVisitStatus.cancelled:
        return AppColors.textTertiary;
    }
  }

  String _formatScheduled(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour == 0
        ? 12
        : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} · $hour:$min $ampm';
  }
}
