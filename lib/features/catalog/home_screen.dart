import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme.dart';
import 'data/repositories/catalog_repository.dart';
import 'domain/models/app_category.dart';
import 'domain/models/product.dart';
import 'domain/models/sub_category.dart';
import 'presentation/widgets/category_row_shimmer.dart';
import 'presentation/widgets/dynamic_product_card.dart';
import 'presentation/widgets/error_retry.dart';
import 'presentation/widgets/product_grid_shimmer.dart';
import 'presentation/widgets/sub_category_row.dart';
import 'widgets/home_sticky_header.dart';

/// Screen states: Loading → Data / Error.
enum _LoadState { loading, data, error }

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

  // Per-tab (subcategory) state
  final Map<String, List<SubCategory>> _subCatsByTop = {};
  final Map<String, _LoadState> _subCatStateByTop = {};

  // Per-tab (products) state — cached by CACHE KEY (topCatId + optional subCatId)
  final Map<String, List<Product>> _productsByKey = {};
  final Map<String, _LoadState> _productStateByKey = {};

  // Active subcategory per top-category tab (null = "All" in that tab)
  final Map<String, String?> _activeSubByTop = {};

  TabController? _tabController;
  int _activeIndex = 0;
  bool _userTappedTab = false;

  // Monotonic request counter to prevent stale responses from overwriting
  // newer state when user switches tabs fast.
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _loadTopCategories();
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

      // Rebuild TabController for the actual tab count
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
        _ensureProductsLoaded(cats.first.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _topCategoryError = e.toString();
        _topCategoryState = _LoadState.error;
      });
    }
  }

  /// Build cache key for products: either "topId" or "topId|subId".
  String _productKey(String topCategoryId, {String? subCategoryId}) =>
      subCategoryId == null ? topCategoryId : '$topCategoryId|$subCategoryId';

  void _onTabSelected(int index) {
    final cat = _topCategories[index];
    final activeSubForNewTab = _activeSubByTop[cat.id]; // restore last sub
    setState(() {
      _activeIndex = index;
      _userTappedTab = true;
    });
    _ensureSubCategoriesLoaded(cat.id);
    _ensureProductsLoaded(cat.id, subCategoryId: activeSubForNewTab);
  }

  void _onSubCategoryTapped(String topCategoryId, SubCategory sub) {
    final current = _activeSubByTop[topCategoryId];
    // Toggle: tap same sub again deselects (shows all in top category)
    final next = current == sub.id ? null : sub.id;
    setState(() => _activeSubByTop[topCategoryId] = next);
    _ensureProductsLoaded(topCategoryId, subCategoryId: next);
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

  Future<void> _ensureProductsLoaded(
    String topCategoryId, {
    String? subCategoryId,
  }) async {
    final key = _productKey(topCategoryId, subCategoryId: subCategoryId);

    if (_productsByKey.containsKey(key) &&
        _productStateByKey[key] == _LoadState.data) {
      return;
    }

    // Bump request sequence: any response from a PREVIOUS fetch is ignored.
    final seq = ++_requestSeq;

    setState(() {
      _productStateByKey[key] = _LoadState.loading;
      // Don't touch other keys — per-cache-key isolation.
    });

    try {
      final products = subCategoryId == null
          ? await _repo.getProductsByTopCategory(topCategoryId)
          : await _repo.getProductsBySubCategory(subCategoryId);

      // Race guard: drop response if user switched tabs / subcategories in the meantime
      if (!mounted || seq != _requestSeq) return;

      setState(() {
        _productsByKey[key] = products;
        _productStateByKey[key] = _LoadState.data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _productStateByKey[key] = _LoadState.error);
    }
  }

  Future<void> _refresh() async {
    final active = _activeCategory;
    if (active == null) {
      await _loadTopCategories();
      return;
    }
    final activeSub = _activeSubByTop[active.id];
    final key = _productKey(active.id, subCategoryId: activeSub);

    _subCatsByTop.remove(active.id);
    _productsByKey.remove(key);
    _productStateByKey.remove(key);
    await Future.wait([
      _ensureSubCategoriesLoaded(active.id),
      _ensureProductsLoaded(active.id, subCategoryId: activeSub),
    ]);
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
    // Top categories: loading
    if (_topCategoryState == _LoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Top categories: error
    if (_topCategoryState == _LoadState.error || _topCategories.isEmpty) {
      return ErrorRetry(
        message: _topCategoryError ?? 'Failed to load catalog. Please try again.',
        onRetry: _loadTopCategories,
      );
    }

    final active = _activeCategory!;
    final activeSub = _activeSubByTop[active.id];
    final productKey = _productKey(active.id, subCategoryId: activeSub);

    final subState = _subCatStateByTop[active.id];
    final prodState = _productStateByKey[productKey];
    final subs = _subCatsByTop[active.id] ?? [];
    final products = _productsByKey[productKey] ?? [];

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.accent,
      child: CustomScrollView(
        slivers: [
          // Sticky header
          SliverPersistentHeader(
            pinned: true,
            delegate: HomeStickyHeader(
              tabController: _tabController!,
              tabLabels: _topCategories.map((c) => c.name).toList(),
              onSearchTap: () => context.push('/search'),
              onNotificationTap: () {},
              onProfileTap: () => context.push('/profile'),
              onTabTap: _onTabSelected,
            ),
          ),

          // Subcategory row (after user taps a tab)
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
          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // Lookbook CTA
          SliverToBoxAdapter(child: _buildLookbookCta()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // Section title
          SliverToBoxAdapter(child: _buildSectionTitle(active, products.length)),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Product grid / loading / error
          _buildProductSliver(prodState, products, active),

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
      selectedId: _activeSubByTop[active.id],
      onTap: (cat) => _onSubCategoryTapped(active.id, cat),
    );
  }

  Widget _buildProductSliver(
      _LoadState? state, List<Product> products, AppCategory active) {
    if (state == _LoadState.loading) {
      return const SliverToBoxAdapter(child: ProductGridShimmer());
    }
    if (state == _LoadState.error) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 280,
          child: ErrorRetry(
            message: 'Could not load products.',
            onRetry: () => _ensureProductsLoaded(
              active.id,
              subCategoryId: _activeSubByTop[active.id],
            ),
          ),
        ),
      );
    }
    if (products.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 48,
                  color: AppColors.textTertiary.withAlpha(80),
                ),
                const SizedBox(height: 12),
                Text(
                  'No products yet — check back soon!',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final p = products[index];
            return DynamicProductCard(
              product: p,
              onTap: () => context.push('/product/${p.id}'),
            );
          },
          childCount: products.length,
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

  Widget _buildLookbookCta() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => context.push('/lookbook'),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(
              image: const NetworkImage(
                'https://images.unsplash.com/photo-1558171813-4c088753af8f?w=800',
              ),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                AppColors.primary.withAlpha(180),
                BlendMode.darken,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LOOKBOOK',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        color: AppColors.accentContainer,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Explore Our\nFabric Collection',
                      style: GoogleFonts.newsreader(
                        fontSize: 22,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Handpicked silks, linens & more',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Colors.white.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(AppCategory active, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'For ${active.name}',
                style: GoogleFonts.newsreader(
                  fontSize: 22,
                  fontStyle: FontStyle.italic,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '$count',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () => context.push('/catalog'),
            child: Text(
              'See all',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
