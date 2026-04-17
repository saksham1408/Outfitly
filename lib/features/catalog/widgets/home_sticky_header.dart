import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';

/// Myntra-style sticky header for the home feed.
/// Contains: Top row (location + icons) + Search bar + Gender tabs.
class HomeStickyHeader extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final VoidCallback onSearchTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;
  final ValueChanged<int>? onTabTap;

  HomeStickyHeader({
    required this.tabController,
    required this.onSearchTap,
    required this.onNotificationTap,
    required this.onProfileTap,
    this.onTabTap,
  });

  // Heights per row
  static const double _topRowHeight = 52;
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
                      // Location picker
                      Expanded(
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
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Mumbai 400001',
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
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Notification with badge
                      _iconWithBadge(
                        icon: Icons.notifications_none_rounded,
                        badge: '3',
                        onTap: onNotificationTap,
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
              tabs: const [
                Tab(text: 'MEN'),
                Tab(text: 'WOMEN'),
                Tab(text: 'KIDS'),
              ],
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
