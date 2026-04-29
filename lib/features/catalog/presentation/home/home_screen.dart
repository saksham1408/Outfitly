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

          // NOTE: The "Book a Home Tailor Visit" CTA used to live here
          // unconditionally. It has been moved into the Design Studio
          // (after the customer picks a fabric) so the offer surfaces at
          // the moment it's actually relevant — once you've chosen a
          // cloth, getting measured at home becomes the next logical
          // step. See `DesignStudioScreen._buildFabricStep`.

          // ── AI Look Recreator CTA ──
          // Routes into the photo-upload flow where Gemini Vision
          // reverse-engineers an inspiration outfit into a custom
          // blueprint pre-populated for our design studio.
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: _buildRecreateLookCta()),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  /// CTA card that drops the customer into the AI Look Recreator
  /// flow (photo → Gemini → recreated design studio). Sits below
  /// the hero banner as the home screen's single "do something
  /// custom" entry point — the home-tailor-visit offer used to live
  /// next to it, but now waits until the customer picks a fabric in
  /// the design studio.
  Widget _buildRecreateLookCta() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => context.push('/recreate-look'),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accentContainer.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.accentContainer,
                  size: 24,
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
                          'Recreate a Look',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentContainer.withAlpha(60),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'AI',
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
                      'Upload an outfit photo — get a custom blueprint',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Colors.white.withAlpha(180),
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
