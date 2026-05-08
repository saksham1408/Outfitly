import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../addresses/data/address_service.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/app_category.dart';
import '../../domain/models/sub_category.dart';
import '../widgets/category_row_shimmer.dart';
import '../widgets/error_retry.dart';
import '../widgets/sub_category_row.dart';
import 'widgets/home_sticky_header.dart';

/// Screen states: Loading → Data / Error.
enum _LoadState { loading, data, error }

/// The Home screen shows only:
///   • Top tabs (MEN / WOMEN / KIDS)
///   • Horizontal list of subcategory circles
///   • Hero banner
///
/// Tapping a subcategory pushes the user into a dedicated PLP
/// (`SubcategoryScreen`) via `/subcategory/:id`. The product grid itself
/// lives on that dedicated screen, not here.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final _repo = CatalogRepository();

  // Top categories
  List<AppCategory> _topCategories = [];
  _LoadState _topCategoryState = _LoadState.loading;
  String? _topCategoryError;

  // Per-tab subcategory state
  final Map<String, List<SubCategory>> _subCatsByTop = {};
  final Map<String, _LoadState> _subCatStateByTop = {};

  TabController? _tabController;
  int _activeIndex = 0;
  bool _userTappedTab = false;

  @override
  void initState() {
    super.initState();
    _loadTopCategories();
    // Kick off the live delivery-address resolution. First launch this
    // triggers the OS permission prompt; subsequent launches hydrate
    // from the cached value and silently refresh in the background.
    // Deliberately unawaited — we never want the feed to wait on
    // location.
    LocationService.instance.ensure();
    // Hydrate saved addresses so the delivery pill shows the
    // currently-selected one immediately on cold launch (no flicker).
    AddressService.instance.ensureLoaded();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  AppCategory? get _activeCategory =>
      _topCategories.isNotEmpty ? _topCategories[_activeIndex] : null;

  Future<void> _loadTopCategories() async {
    setState(() {
      _topCategoryState = _LoadState.loading;
      _topCategoryError = null;
    });

    try {
      final cats = await _repo.getTopCategories();
      if (!mounted) return;

      _tabController?.dispose();
      _tabController = TabController(length: cats.length, vsync: this);
      _tabController!.addListener(() {
        if (_tabController!.indexIsChanging) return;
        _onTabSelected(_tabController!.index);
      });

      setState(() {
        _topCategories = cats;
        _activeIndex = 0;
        _topCategoryState = _LoadState.data;
      });

      if (cats.isNotEmpty) {
        _ensureSubCategoriesLoaded(cats.first.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _topCategoryError = e.toString();
        _topCategoryState = _LoadState.error;
      });
    }
  }

  void _onTabSelected(int index) {
    final cat = _topCategories[index];
    setState(() {
      _activeIndex = index;
      _userTappedTab = true;
    });
    _ensureSubCategoriesLoaded(cat.id);
  }

  /// Push the dedicated PLP for the tapped subcategory.
  /// The subcategory name is passed via `extra` so the new screen can show
  /// it in the AppBar without an extra network round-trip.
  void _onSubCategoryTapped(SubCategory sub) {
    context.push('/subcategory/${sub.id}', extra: sub.name);
  }

  Future<void> _ensureSubCategoriesLoaded(String categoryId) async {
    if (_subCatsByTop.containsKey(categoryId) &&
        _subCatStateByTop[categoryId] == _LoadState.data) {
      return;
    }
    setState(() {
      _subCatStateByTop[categoryId] = _LoadState.loading;
    });
    try {
      final subs = await _repo.getSubCategories(categoryId);
      if (!mounted) return;
      setState(() {
        _subCatsByTop[categoryId] = subs;
        _subCatStateByTop[categoryId] = _LoadState.data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _subCatStateByTop[categoryId] = _LoadState.error);
    }
  }

  Future<void> _refresh() async {
    final active = _activeCategory;
    if (active == null) {
      await _loadTopCategories();
      return;
    }
    _subCatsByTop.remove(active.id);
    await _ensureSubCategoriesLoaded(active.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_topCategoryState == _LoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_topCategoryState == _LoadState.error || _topCategories.isEmpty) {
      return ErrorRetry(
        message:
            _topCategoryError ?? 'Failed to load catalog. Please try again.',
        onRetry: _loadTopCategories,
      );
    }

    final active = _activeCategory!;
    final subState = _subCatStateByTop[active.id];
    final subs = _subCatsByTop[active.id] ?? [];

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.accent,
      child: CustomScrollView(
        slivers: [
          // Sticky header (top bar + gender tabs)
          SliverPersistentHeader(
            pinned: true,
            delegate: HomeStickyHeader(
              tabController: _tabController!,
              tabLabels: _topCategories.map((c) => c.name).toList(),
              onSearchTap: () => context.push('/search'),
              onNotificationTap: () {},
              onProfileTap: () => context.push('/profile'),
              onWishlistTap: () => context.push('/wishlist'),
              onCartTap: () => context.push('/cart'),
              onOffersTap: () => context.push('/offers'),
              onTabTap: _onTabSelected,
            ),
          ),

          // Subcategory row — shown once user taps a tab
          if (_userTappedTab) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: _buildSubCategoryRow(subState, subs, active),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ] else
            const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Hero banner
          SliverToBoxAdapter(child: _buildHeroBanner()),

          // ── Stitch My Fabric premium entry ──
          // Sits directly under the hero strip so a customer who
          // already owns unstitched fabric sees the doorstep-
          // tailor service before scrolling further. Routes into
          // the isolated CustomStitchingDashboardScreen at
          // /custom-stitching/dashboard.
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: _buildStitchMyFabricCta()),

          // ── Family & Combos premium entry ──
          // Anchored just under the Stitch My Fabric card so the
          // two flagship CTAs read as a stacked pair before the
          // long-tail content below kicks in. Routes into the
          // Couple-vs-Family fork at /combo-selection.
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _buildFamilyCombosCta()),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildSubCategoryRow(
      _LoadState? state, List<SubCategory> subs, AppCategory active) {
    if (state == _LoadState.loading) return const CategoryRowShimmer();
    if (state == _LoadState.error) {
      return SizedBox(
        height: 96,
        child: Center(
          child: TextButton.icon(
            onPressed: () => _ensureSubCategoriesLoaded(active.id),
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(
              'Retry subcategories',
              style: GoogleFonts.manrope(fontSize: 12),
            ),
          ),
        ),
      );
    }
    if (subs.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'No subcategories yet.',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      );
    }
    return SubCategoryRow(
      subCategories: subs,
      // No persistent selection on Home — each tap navigates away to the PLP.
      selectedId: null,
      onTap: _onSubCategoryTapped,
    );
  }

  /// Premium "Stitch My Fabric" CTA — the marquee surface for
  /// the isolated doorstep-tailor service line. Anchored
  /// directly beneath the hero strip so a customer who already
  /// owns unstitched fabric never has to hunt for the entry
  /// point. Sewing-machine icon + measuring-tape-styled palette
  /// distinguish it from the Family & Combos card stacked below.
  /// Tap routes to /custom-stitching/dashboard, which is its own
  /// tracker (never bleeds into /orders).
  Widget _buildStitchMyFabricCta() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/custom-stitching/dashboard'),
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF8B500A),
                  Color(0xFF17362E),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(60),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
            child: Row(
              children: [
                // Icon block — slightly oversized vs the Combos
                // card so the Stitch CTA reads as the louder of
                // the two stacked entries.
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(38),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.content_cut_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Have your own fabric?',
                              style: GoogleFonts.newsreader(
                                fontSize: 18,
                                fontStyle: FontStyle.italic,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.accentContainer.withAlpha(80),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'NEW',
                              style: GoogleFonts.manrope(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.accentContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'We\'ll stitch it.',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Book Doorstep Tailor & Fabric Pickup',
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
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
      ),
    );
  }

  /// Premium "Family & Combos" CTA card — anchored just under
  /// the hero banner. Visually distinct (deep purple → amber
  /// gradient with a family-restroom icon as a textural beat)
  /// so the eye lands on it as a separate offer from whatever
  /// merch is running in the hero strip above. Tap routes to
  /// the Couple-vs-Family fork.
  Widget _buildFamilyCombosCta() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/combo-selection'),
          borderRadius: BorderRadius.circular(18),
          child: Container(
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
            padding: const EdgeInsets.all(18),
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
                    Icons.family_restroom_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Family & Combos',
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentContainer.withAlpha(80),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'NEW',
                              style: GoogleFonts.manrope(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.accentContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Couple looks + full-family sets — coordinated palette, one tap',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Colors.white.withAlpha(200),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withAlpha(170),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Craft Your\nSignature Look',
              style: GoogleFonts.newsreader(
                fontSize: 24,
                fontStyle: FontStyle.italic,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Custom-stitched from fabric to finish',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: Colors.white.withAlpha(200),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
