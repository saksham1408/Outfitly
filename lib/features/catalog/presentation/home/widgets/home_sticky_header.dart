import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/location/location_service.dart';
import '../../../../../core/theme/theme.dart';
import '../../../../addresses/data/address_service.dart';
import '../../../../addresses/models/saved_address.dart';
import '../../../../addresses/presentation/delivery_address_sheet.dart';

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

  // The top row now hosts a single-line pill button, so 56dp is enough
  // breathing room. Search + tabs are unchanged.
  static const double _topRowHeight = 56;
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
                  // Asymmetric padding: 16dp on the left for the
                  // pill, 6dp on the right so the rightmost
                  // (Profile) icon sits flush against the screen
                  // edge as requested.
                  padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
                  // `spaceBetween` is the layout that gives us
                  // exactly what we want: pill anchored to the
                  // left, icon cluster anchored to the right,
                  // and ALL the leftover horizontal space turned
                  // into a single visual gap between them. As
                  // the pill widens (e.g. a long saved-address
                  // label), the gap automatically narrows; if
                  // the pill ever needs to shrink, the inner
                  // Flexible lets it do so without overflowing.
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ── Location pill (left edge, flexible) ──
                      Flexible(child: _DeliveryPillButton()),

                      // ── Action cluster (right edge) ──
                      // mainAxisSize.min so the inner row hugs
                      // its children — keeps the cluster tight
                      // against the right border, regardless of
                      // how wide the outer row is.
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                          IconButton(
                            onPressed: onProfileTap,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon: const Icon(
                              Icons.person_outline_rounded,
                              size: 22,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
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
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Icon(icon, size: 22, color: AppColors.primary),
        ),
        Positioned(
          top: 2,
          right: 0,
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

/// Premium, single-line pill showing the active delivery label with a
/// down-chevron. Tapping opens [showDeliveryAddressSheet] — the sheet
/// itself owns the GPS / saved-addresses / add-new flow.
///
/// Label priority:
///   1. Selected saved address → e.g. "Home" or "Work"
///   2. Detected city (LocationService) → e.g. "Jaipur"
///   3. Fallback → "Set location"
class _DeliveryPillButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SavedAddress>>(
      valueListenable: AddressService.instance.addresses,
      builder: (context, addresses, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: AddressService.instance.selectedId,
          builder: (context, selectedId, __) {
            return ValueListenableBuilder<LocationStatus>(
              valueListenable: LocationService.instance.status,
              builder: (context, status, ___) {
                return ValueListenableBuilder<DeliveryLocation?>(
                  valueListenable: LocationService.instance.location,
                  builder: (context, loc, ____) {
                    final selected = _selectedFromList(addresses, selectedId);
                    final label = _label(selected, loc, status);
                    final subtitle = _subtitle(selected, loc, status);
                    return _PillShell(
                      label: label,
                      subtitle: subtitle,
                      showSpinner: status == LocationStatus.loading &&
                          selected == null,
                      onTap: () => showDeliveryAddressSheet(context),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  SavedAddress? _selectedFromList(List<SavedAddress> list, String? id) {
    if (id == null) return null;
    for (final a in list) {
      if (a.id == id) return a;
    }
    return null;
  }

  String _label(
    SavedAddress? selected,
    DeliveryLocation? loc,
    LocationStatus status,
  ) {
    if (selected != null) return selected.label.titleCase;
    if (loc != null && loc.city.trim().isNotEmpty) return loc.city.trim();
    return switch (status) {
      LocationStatus.loading => 'Detecting…',
      _ => 'Set location',
    };
  }

  String? _subtitle(
    SavedAddress? selected,
    DeliveryLocation? loc,
    LocationStatus status,
  ) {
    if (selected != null) return selected.shortLabel;
    if (loc != null) {
      final trimmed = loc.displayLabel.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return switch (status) {
      LocationStatus.denied => 'Enable location access',
      LocationStatus.servicesDisabled => 'Location services off',
      LocationStatus.error => 'Tap to choose',
      _ => 'Tap to pick your address',
    };
  }
}

class _PillShell extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool showSpinner;
  final VoidCallback onTap;

  const _PillShell({
    required this.label,
    required this.subtitle,
    required this.showSpinner,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.border.withAlpha(100),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withAlpha(18),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSpinner)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: AppColors.primary,
                  ),
                )
              else
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          color: AppColors.textTertiary,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
