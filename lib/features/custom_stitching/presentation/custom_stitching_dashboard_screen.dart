import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/theme.dart';
import '../data/custom_stitching_repository.dart';
import '../models/custom_stitch_order.dart';

/// "Stitch My Fabric" hub.
///
/// This screen is intentionally isolated from the standard
/// `OrdersScreen` — the customer reads only `custom_stitch_orders`
/// rows (via [CustomStitchingRepository.fetchUserCustomOrders]),
/// never bleeding into catalog purchases or the bespoke-design
/// flow's `tailor_appointments`.
///
/// Layout:
///   • Top — bold "Book New Pickup" CTA so the primary action
///     stays one tap away even when the list scrolls.
///   • Bottom — vertical list of every booking the user has,
///     each card rendering a five-step timeline that reflects
///     `status` straight from Postgres.
class CustomStitchingDashboardScreen extends StatefulWidget {
  const CustomStitchingDashboardScreen({super.key});

  @override
  State<CustomStitchingDashboardScreen> createState() =>
      _CustomStitchingDashboardScreenState();
}

class _CustomStitchingDashboardScreenState
    extends State<CustomStitchingDashboardScreen> {
  final _repo = CustomStitchingRepository.instance;
  bool _initialFetching = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    await _repo.fetchUserCustomOrders();
    if (mounted) setState(() => _initialFetching = false);
  }

  Future<void> _refresh() async {
    await _repo.fetchUserCustomOrders();
  }

  void _bookNewPickup() {
    context.push('/custom-stitching/book');
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
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Stitch My Fabric',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.accent,
          child: ValueListenableBuilder<List<CustomStitchOrder>>(
            valueListenable: _repo.orders,
            builder: (context, orders, _) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  _IntroBlock(),
                  const SizedBox(height: 18),
                  _BookNewPickupCta(onTap: _bookNewPickup),
                  const SizedBox(height: 28),
                  Text(
                    'Your Bookings',
                    style: GoogleFonts.newsreader(
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                      color: AppColors.primary,
                      height: 1.1,
                    ),
                  ),
                  Container(
                    height: 2,
                    width: 48,
                    margin: const EdgeInsets.only(top: 6),
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 16),
                  if (_initialFetching && orders.isEmpty)
                    const _DashboardLoading()
                  else if (orders.isEmpty)
                    const _EmptyState()
                  else
                    for (final order in orders) ...[
                      _OrderTimelineCard(order: order),
                      const SizedBox(height: 14),
                    ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Sub-widgets
// ────────────────────────────────────────────────────────────

class _IntroBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Doorstep Tailor',
          style: GoogleFonts.newsreader(
            fontSize: 26,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
            height: 1.1,
          ),
        ),
        Container(
          height: 2,
          width: 56,
          margin: const EdgeInsets.only(top: 6),
          color: AppColors.accent,
        ),
        const SizedBox(height: 10),
        Text(
          'Track every fabric we\'ve picked up — measurements, stitching, and final delivery, all in one place.',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _BookNewPickupCta extends StatelessWidget {
  const _BookNewPickupCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                Color(0xFF8B500A),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Book New Pickup',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Schedule a tailor home-visit · take measurements · pick up your fabric',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Colors.white.withAlpha(210),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withAlpha(180),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTimelineCard extends StatelessWidget {
  const _OrderTimelineCard({required this.order});

  final CustomStitchOrder order;

  @override
  Widget build(BuildContext context) {
    final scheduled = DateFormat('EEE, d MMM · h:mm a')
        .format(order.pickupTime.toLocal());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header — garment + status pill ─────────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.content_cut_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.garmentType,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pickup · $scheduled',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: order.status),
            ],
          ),
          if (order.referenceImageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                order.referenceImageUrl!,
                height: 110,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 110,
                  alignment: Alignment.center,
                  color: AppColors.surfaceVariant,
                  child: Text(
                    'Reference unavailable',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(
            color: AppColors.divider,
            height: 1,
          ),
          const SizedBox(height: 14),
          _StatusTimeline(currentStatus: order.status),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.pickupAddress,
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final CustomStitchStatus status;

  @override
  Widget build(BuildContext context) {
    final isDelivered = status == CustomStitchStatus.delivered;
    final color = isDelivered ? AppColors.success : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.displayLabel,
        style: GoogleFonts.manrope(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }
}

/// Vertical 4-step stepper. The customer sees only the four
/// "happy-path" milestones — the dashboard collapses
/// `pending_pickup` ↔ "Tailor Assigned" so the timeline starts
/// the moment the order exists, since by definition the row
/// always has a tailor on the way.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.currentStatus});

  final CustomStitchStatus currentStatus;

  static const _steps = <CustomStitchStatus>[
    CustomStitchStatus.pendingPickup,
    CustomStitchStatus.fabricCollected,
    CustomStitchStatus.stitching,
    CustomStitchStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex =
        _steps.indexWhere((s) => s.timelineIndex >= currentStatus.timelineIndex);
    final activeIdx = currentIndex == -1 ? _steps.length - 1 : currentIndex;

    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++)
          _TimelineRow(
            label: _steps[i].displayLabel,
            isActive: i <= activeIdx,
            isCurrent: i == activeIdx &&
                currentStatus != CustomStitchStatus.delivered,
            isLast: i == _steps.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.isActive,
    required this.isCurrent,
    required this.isLast,
  });

  final String label;
  final bool isActive;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.border;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: isActive ? color : AppColors.surface,
                  border: Border.all(color: color, width: 2),
                  shape: BoxShape.circle,
                ),
                child: isCurrent
                    ? Container(
                        margin: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: color,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color:
                    isActive ? AppColors.textPrimary : AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(15)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.checkroom_rounded,
            size: 36,
            color: AppColors.primary.withAlpha(140),
          ),
          const SizedBox(height: 10),
          Text(
            'No bookings yet',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Book your first fabric pickup and we\'ll track it for you here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
