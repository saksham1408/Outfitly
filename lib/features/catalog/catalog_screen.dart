import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme.dart';
import 'catalog_service.dart';
import 'models/category_model.dart';
import 'models/product_filters.dart';
import 'models/product_model.dart';
import 'widgets/filter_bottom_sheet.dart';
import 'widgets/product_card.dart';
import 'widgets/sort_bottom_sheet.dart';
import 'widgets/sort_filter_bar.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _catalogService = CatalogService();

  List<CategoryModel> _categories = [];
  List<ProductModel> _products = [];
  String? _selectedCategoryId;
  bool _loading = true;

  // Filter + sort state
  ProductFilters _filters = ProductFilters();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _catalogService.getCategories();
      if (!mounted) return;
      setState(() => _categories = cats);
      await _loadProducts(null);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProducts(String? categoryId) async {
    setState(() {
      _loading = true;
      _selectedCategoryId = categoryId;
    });

    try {
      final products = categoryId != null
          ? await _catalogService.getProductsByCategory(categoryId)
          : await _catalogService.getFeaturedProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Applies sort + filters to _products on the fly (client-side).
  List<ProductModel> get _visibleProducts {
    var list = List<ProductModel>.from(_products);

    // ── Filter: Fabric (multi) ──
    final fabrics = _filters.selectedOptions[FilterCategory.fabric] ?? {};
    if (fabrics.isNotEmpty) {
      list = list.where((p) {
        return p.fabricOptions.any(
          (fo) => fabrics.any((f) => fo.toLowerCase().contains(f.toLowerCase())),
        );
      }).toList();
    }

    // ── Filter: Price Range (single) ──
    final priceRanges =
        _filters.selectedOptions[FilterCategory.priceRange] ?? {};
    if (priceRanges.isNotEmpty) {
      final range = priceRanges.first;
      list = list.where((p) => _matchesPriceRange(p.basePrice, range)).toList();
    }

    // ── Filter: Quick Filters ──
    final quick = _filters.selectedOptions[FilterCategory.quickFilters] ?? {};
    if (quick.contains('Under ₹2,000')) {
      list = list.where((p) => p.basePrice < 2000).toList();
    }
    if (quick.contains('Bestseller')) {
      list = list.where((p) => p.isFeatured).toList();
    }

    // ── Sort ──
    switch (_filters.sort) {
      case SortOption.priceLowToHigh:
        list.sort((a, b) => a.basePrice.compareTo(b.basePrice));
        break;
      case SortOption.priceHighToLow:
        list.sort((a, b) => b.basePrice.compareTo(a.basePrice));
        break;
      case SortOption.popularity:
        list.sort((a, b) => (b.isFeatured ? 1 : 0) - (a.isFeatured ? 1 : 0));
        break;
      case SortOption.discount:
      case SortOption.customerRating:
      case SortOption.whatsNew:
        // Server already returns created_at desc; no-op.
        break;
    }

    return list;
  }

  bool _matchesPriceRange(double price, String label) {
    switch (label) {
      case '₹0 – ₹2,000':
        return price >= 0 && price <= 2000;
      case '₹2,000 – ₹5,000':
        return price > 2000 && price <= 5000;
      case '₹5,000 – ₹10,000':
        return price > 5000 && price <= 10000;
      case '₹10,000 – ₹20,000':
        return price > 10000 && price <= 20000;
      case '₹20,000+':
        return price > 20000;
      default:
        return true;
    }
  }

  Future<void> _openSort() async {
    final result = await showSortBottomSheet(context, current: _filters.sort);
    if (result != null) {
      setState(() => _filters.sort = result);
    }
  }

  Future<void> _openFilter() async {
    final result = await showFilterBottomSheet(context, current: _filters);
    if (result != null) {
      setState(() => _filters = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleProducts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Catalog'),
      ),
      body: Column(
        children: [
          // ── Category Filter Chips ──
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              itemCount: _categories.length + 1,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = _selectedCategoryId == null;
                  return ChoiceChip(
                    label: const Text('All'),
                    selected: isSelected,
                    onSelected: (_) => _loadProducts(null),
                    selectedColor: AppColors.primary,
                    labelStyle: AppTypography.labelMedium.copyWith(
                      color: isSelected
                          ? AppColors.textOnPrimary
                          : AppColors.textPrimary,
                    ),
                    showCheckmark: false,
                  );
                }

                final cat = _categories[index - 1];
                final isSelected = _selectedCategoryId == cat.id;
                return ChoiceChip(
                  label: Text(cat.name),
                  selected: isSelected,
                  onSelected: (_) => _loadProducts(cat.id),
                  selectedColor: AppColors.primary,
                  labelStyle: AppTypography.labelMedium.copyWith(
                    color: isSelected
                        ? AppColors.textOnPrimary
                        : AppColors.textPrimary,
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.base),

          // ── Product Grid ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                    ? Center(
                        child: Text(
                          'No products found',
                          style: AppTypography.bodyMedium,
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenPadding,
                          0,
                          AppSpacing.screenPadding,
                          AppSpacing.base,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: AppSpacing.base,
                          crossAxisSpacing: AppSpacing.base,
                          childAspectRatio: 0.65,
                        ),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final product = visible[index];
                          return ProductCard(
                            product: product,
                            onTap: () =>
                                context.push('/product/${product.id}'),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: SortFilterBar(
        onSortTap: _openSort,
        onFilterTap: _openFilter,
        activeFilterCount: _filters.activeFilterCount,
      ),
    );
  }
}
