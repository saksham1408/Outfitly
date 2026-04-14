import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme.dart';
import 'catalog_service.dart';
import 'models/category_model.dart';
import 'models/product_model.dart';
import 'widgets/product_card.dart';

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
      // Load all featured initially.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Catalog'),
      ),
      body: Column(
        children: [
          // ── Category Filter ──
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
                : _products.isEmpty
                    ? Center(
                        child: Text(
                          'No products found',
                          style: AppTypography.bodyMedium,
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPadding,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: AppSpacing.base,
                          crossAxisSpacing: AppSpacing.base,
                          childAspectRatio: 0.65,
                        ),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
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
    );
  }
}
