import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme.dart';
import 'catalog_service.dart';
import 'models/category_model.dart';
import 'models/product_model.dart';
import 'widgets/category_chip.dart';
import 'widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _catalogService = CatalogService();

  List<CategoryModel> _categories = [];
  List<ProductModel> _featured = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _catalogService.getCategories(),
        _catalogService.getFeaturedProducts(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<CategoryModel>;
        _featured = results[1] as List<ProductModel>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.accent,
                child: CustomScrollView(
                  slivers: [
                    // ── Header ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenPadding,
                          AppSpacing.lg,
                          AppSpacing.screenPadding,
                          AppSpacing.base,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'OUTFITLY',
                                  style: AppTypography.headlineLarge.copyWith(
                                    letterSpacing: 4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Bespoke, just for you',
                                  style: AppTypography.bodySmall,
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => context.push('/catalog'),
                                  icon: const Icon(Icons.search_rounded),
                                ),
                                IconButton(
                                  onPressed: () => context.push('/cart'),
                                  icon: const Icon(
                                    Icons.shopping_bag_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Categories ──
                    if (_categories.isNotEmpty)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.screenPadding,
                            ),
                            itemCount: _categories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final cat = _categories[index];
                              return CategoryChip(
                                label: cat.name,
                                onTap: () => context.push('/catalog'),
                              );
                            },
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xl),
                    ),

                    // ── Hero Banner ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPadding,
                        ),
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusLg,
                            ),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Craft Your\nSignature Look',
                                style: AppTypography.displaySmall.copyWith(
                                  color: AppColors.textOnPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Custom-stitched from fabric to finish',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textOnPrimary
                                      .withAlpha(180),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xxl),
                    ),

                    // ── Lookbook CTA ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPadding,
                        ),
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

                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xxl),
                    ),

                    // ── Featured Section Title ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPadding,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Featured',
                              style: AppTypography.headlineMedium,
                            ),
                            TextButton(
                              onPressed: () => context.push('/catalog'),
                              child: const Text('See all'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Featured Grid ──
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: AppSpacing.base,
                          crossAxisSpacing: AppSpacing.base,
                          childAspectRatio: 0.65,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = _featured[index];
                            return ProductCard(
                              product: product,
                              onTap: () =>
                                  context.push('/product/${product.id}'),
                            );
                          },
                          childCount: _featured.length,
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.huge),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
