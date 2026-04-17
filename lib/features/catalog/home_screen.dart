import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme.dart';
import 'catalog_service.dart';
import 'models/product_model.dart';
import 'widgets/home_sticky_header.dart';
import 'widgets/men_category_row.dart';
import 'widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _catalogService = CatalogService();
  late final TabController _tabController;

  List<ProductModel> _allProducts = [];
  bool _loading = true;

  // Active tab filter: 'all', 'men', 'women', 'kids'
  static const _genderTabs = ['all', 'men', 'women', 'kids'];
  String _activeGender = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _activeGender = _genderTabs[_tabController.index];
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final products = await _catalogService.getAllProducts();
      if (!mounted) return;
      setState(() {
        _allProducts = products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<ProductModel> get _filteredProducts {
    if (_activeGender == 'all') return _allProducts;
    return _allProducts
        .where((p) => p.gender == _activeGender || p.gender == 'all')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.accent,
                child: CustomScrollView(
                  slivers: [
                    // ── Sticky Header ──
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: HomeStickyHeader(
                        tabController: _tabController,
                        onSearchTap: () => context.push('/catalog'),
                        onNotificationTap: () {},
                        onProfileTap: () => context.push('/profile'),
                      ),
                    ),

                    // ── MEN Categories (shown ONLY on MEN tab) ──
                    if (_activeGender == 'men') ...[
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      SliverToBoxAdapter(
                        child: MenCategoryRow(
                          onCategoryTap: (cat) => context.push('/catalog'),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ] else
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),

                    // ── Hero Banner ──
                    SliverToBoxAdapter(
                      child: Padding(
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
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 28)),

                    // ── Lookbook CTA ──
                    SliverToBoxAdapter(
                      child: Padding(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 32)),

                    // ── Section Title with active filter ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _activeGender == 'all'
                                      ? 'For You'
                                      : 'For ${_activeGender[0].toUpperCase()}${_activeGender.substring(1)}',
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
                                    '${_filteredProducts.length}',
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
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    // ── Filtered Product Grid ──
                    if (_filteredProducts.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 48,
                                  color: AppColors.textTertiary.withAlpha(80),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No products in this category yet',
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.65,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final product = _filteredProducts[index];
                              return ProductCard(
                                product: product,
                                onTap: () =>
                                    context.push('/product/${product.id}'),
                              );
                            },
                            childCount: _filteredProducts.length,
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              ),
      ),
    );
  }

}
