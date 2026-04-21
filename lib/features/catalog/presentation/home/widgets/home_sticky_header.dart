import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/location/location_service.dart';
import '../../../../../core/theme/theme.dart';

/// Myntra-style sticky header for the home feed.
/// Contains: Top row (location + icons) + Search bar + Gender tabs.
class HomeStickyHeader extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final VoidCallback onSearchTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;
  final VoidCallback onWishlistTap;
  final VoidCallback onCartTap;
  final ValueChanged<int>? onTabTap;
  final List<String> tabLabels;

  HomeStickyHeader({
    required this.tabController,
    required this.onSearchTap,
    required this.onNotificationTap,
    required this.onProfileTap,
    required this.onWishlistTap,
    required this.onCartTap,
    this.onTabTap,
    this.tabLabels = const ['MEN', 'WOMEN', 'KIDS'],
  });

  // Heights per row. The top row has to host a two-line label ("Deliver
  // to" + a bold city line with a chevron) so 60dp keeps the chevron
  // from crowding the baseline when the city name is long.
  static const double _topRowHeight = 60;
  static const double _searchHeight = 56;
  static const double _tabsHeight = 48;
  static const double _totalHeight =
      _topRowHeight + _searchHeight + _tabsHeight;

  @override
  double get minExtent => _searchHeight + _tabsHeight; // top row collapses

  @override
  double get maxExtent => _totalHeight;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapsedRatio = (shrinkOffset / _topRowHeight).clamp(0.0, 1.0);
    final topRowOpacity = 1 - collapsedRatio;

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // ── Top Row (collapses on scroll) ──
          Opacity(
            opacity: topRowOpacity,
            child: SizedBox(
              height: (_topRowHeight * (1 - collapsedRatio)).clamp(
                0.0,
                _topRowHeight,
              ),
              child: OverflowBox(
                minHeight: 0,
                maxHeight: _topRowHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Location picker — live, bound to LocationService.
                      Expanded(
                        child: _LiveDeliveryChip(
                          onOpenSettings: () =>
                              LocationService.instance.openAppSettings(),
                          onOpenLocationServices: () =>
                              LocationService.instance.openLocationSettings(),
                        ),
                      ),

                      // Right-side actions
                      _iconWithBadge(
                        icon: Icons.notifications_none_rounded,
                        badge: '3',
                        onTap: onNotificationTap,
                      ),
                      _iconWithBadge(
                        icon: Icons.favorite_border,
                        badge: '5',
                        onTap: onWishlistTap,
                      ),
                      _iconWithBadge(
                        icon: Icons.shopping_bag_outlined,
                        badge: '2',
                        onTap: onCartTap,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: onProfileTap,
                        icon: const Icon(
                          Icons.person_outline_rounded,
                          size: 24,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Search Bar (pinned) ──
          Container(
            height: _searchHeight,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: GestureDetector(
              onTap: onSearchTap,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border.withAlpha(60),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Search for fabrics, kurtas, suits...',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.mic_none_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.camera_alt_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Gender Tabs (pinned) ──
          Container(
            height: _tabsHeight,
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.border.withAlpha(60),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: tabController,
              onTap: onTabTap,
              isScrollable: false,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textTertiary,
              labelStyle: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
              unselectedLabelStyle: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(
                  color: AppColors.accent,
                  width: 3,
                ),
                insets: EdgeInsets.symmetric(horizontal: 24),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              tabs: tabLabels.map((l) => Tab(text: l.toUpperCase())).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconWithBadge({
    required IconData icon,
    required String badge,
    required VoidCallback onTap,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 24, color: AppColors.primary),
        ),
        Positioned(
          top: 6,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.background,
                width: 1.5,
              ),
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: Text(
              badge,
              style: GoogleFonts.manrope(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

/// Live "Deliver to …" chip that listens to [LocationService]. Tapping
/// the chip triggers a refresh (first-tap also drives the OS permission
/// prompt). State handling:
///
/// | LocationStatus       | Subtitle rendered           |
/// |----------------------|-----------------------------|
/// | idle                 | "Tap to detect location"    |
/// | loading              | animated "Detecting…"        |
/// | resolved + location  | "`City Pincode`"            |
/// | denied               | "Enable location access"    |
/// | servicesDisabled     | "Turn on Location Services" |
/// | error                | "Tap to retry"              |
class _LiveDeliveryChip extends StatelessWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenLocationServices;

  const _LiveDeliveryChip({
    required this.onOpenSettings,
    required this.onOpenLocationServices,
  });

  Future<void> _handleTap(BuildContext context) async {
    final svc = LocationService.instance;
    final status = svc.status.value;
    // Permission was permanently refused — can't re-prompt from Dart,
    // only nudge the user into Settings.
    if (status == LocationStatus.denied) {
      final go = await _askToOpenSettings(
        context,
        title: 'Location access needed',
        body:
            'Enable location for VASTRAHUB in Settings so we can pre-fill your delivery address.',
      );
      if (go) onOpenSettings();
      return;
    }
    if (status == LocationStatus.servicesDisabled) {
      final go = await _askToOpenSettings(
        context,
        title: 'Location services are off',
        body:
            'Turn on Location Services in Settings so VASTRAHUB can detect your city.',
      );
      if (go) onOpenLocationServices();
      return;
    }
    // Anything else → re-run the fetch. This is what drives the first
    // permission prompt too.
    await svc.refresh();
  }

  Future<bool> _askToOpenSettings(
    BuildContext context, {
    required String title,
    required String body,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          // Horizontal breathing room so the ripple has a halo, but no
          // vertical padding — the parent row is height-constrained and
          // the 10pt label + 13pt+18pt row already fill it tightly.
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deliver to',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    ValueListenableBuilder<LocationStatus>(
                      valueListenable: LocationService.instance.status,
                      builder: (context, status, _) {
                        return ValueListenableBuilder<DeliveryLocation?>(
                          valueListenable: LocationService.instance.location,
                          builder: (context, loc, __) =>
                              _buildSubtitle(status, loc),
                        );
                      },
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

  Widget _buildSubtitle(LocationStatus status, DeliveryLocation? loc) {
    if (status == LocationStatus.loading) {
      return Row(
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.4,
              color: AppColors.primary.withAlpha(160),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Detecting…',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      );
    }

    // Show cached/resolved label whenever we have one — even for error
    // states, a stale "Mumbai 400001" is more useful than a hint.
    if (loc != null && status != LocationStatus.denied &&
        status != LocationStatus.servicesDisabled) {
      return Row(
        children: [
          Flexible(
            child: Text(
              loc.displayLabel,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.primary,
          ),
        ],
      );
    }

    final hint = switch (status) {
      LocationStatus.denied => 'Enable location access',
      LocationStatus.servicesDisabled => 'Turn on Location Services',
      LocationStatus.error => 'Tap to retry',
      _ => 'Tap to detect location',
    };
    return Row(
      children: [
        Flexible(
          child: Text(
            hint,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 18,
          color: AppColors.primary,
        ),
      ],
    );
  }
}
