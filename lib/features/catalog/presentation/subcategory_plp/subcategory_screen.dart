import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/product.dart';
import '../../models/product_filters.dart';
import '../widgets/dynamic_product_card.dart';
import '../widgets/error_retry.dart';
import '../widgets/product_grid_shimmer.dart';
import 'widgets/filter_bottom_sheet.dart';
import 'widgets/sort_bottom_sheet.dart';
import 'widgets/sort_filter_bar.dart';

enum _LoadState { loading, data, error }

/// Product Listing Page for a single subcategory.
///
/// Route: `/subcategory/:id`, with the subcategory's display name passed
/// via `GoRouterState.extra`. The screen fetches products strictly by
/// `category_id` (subcategory id), shows them in a 2-column grid, and
/// exposes the reusable SORT / FILTER bottom bar.
class SubcategoryScreen extends StatefulWidget {
  final String subcategoryId;

  /// Optional display name used in the AppBar (passed via `extra`).
  /// Falls back to a generic label if not provided.
  final String? subcategoryName;

  const SubcategoryScreen({
    super.key,
    required this.subcategoryId,
    this.subcategoryName,
  });

  @override
  State<SubcategoryScreen> createState() => _SubcategoryScreenState();
}

class _SubcategoryScreenState extends State<SubcategoryScreen> {
  final _repo = CatalogRepository();

  _LoadState _state = _LoadState.loading;
  String? _error;
  List<Product> _products = [];

  // Sort + filter state — kept local to this PLP.
  final ProductFilters _filters = ProductFilters();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _state = _LoadState.loading;
      _error = null;
    });
    try {
      final products =
          await _repo.getProductsBySubCategory(widget.subcategoryId);
      if (!mounted) return;
      setState(() {
        _products = products;
        _state = _LoadState.data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _state = _LoadState.error;
      });
    }
  }

  Future<void> _openSort() async {
    final chosen = await showSortBottomSheet(context, current: _filters.sort);
    if (chosen != null && chosen != _filters.sort) {
      setState(() => _filters.sort = chosen);
    }
  }

  Future<void> _openFilter() async {
    final next =
        await showFilterBottomSheet(context, current: _filters);
    if (next != null) {
      setState(() {
        _filters.sort = next.sort;
        _filters.selectedOptions = next.selectedOptions;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.primary,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(
          widget.subcategoryName ?? 'Products',
          style: GoogleFonts.newsreader(
            fontSize: 20,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        bottom: false,
        child: _buildBody(),
      ),
      bottomNavigationBar: _state == _LoadState.data && _products.isNotEmpty
          ? SortFilterBar(
              onSortTap: _openSort,
              onFilterTap: _openFilter,
              activeFilterCount: _filters.activeFilterCount,
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_state == _LoadState.loading) {
      return const ProductGridShimmer();
    }
    if (_state == _LoadState.error) {
      return ErrorRetry(
        message: _error ?? 'Could not load products.',
        onRetry: _load,
      );
    }
    if (_products.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildCountRow()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                  final p = _products[index];
                  return DynamicProductCard(
                    product: p,
                    onTap: () => context.push('/product/${p.id}'),
                  );
                },
                childCount: _products.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildCountRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            '${_products.length} ${_products.length == 1 ? 'product' : 'products'}',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.textTertiary.withAlpha(80),
            ),
            const SizedBox(height: 16),
            Text(
              'No products yet',
              style: GoogleFonts.newsreader(
                fontSize: 20,
                fontStyle: FontStyle.italic,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "We're still curating this section — check back soon.",
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
