import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../../catalog/models/product_model.dart';

class SearchScreen extends StatefulWidget {
  /// When true, the back arrow is shown (screen was pushed).
  final bool canPop;

  /// Pre-filled query, e.g. from voice search. When non-null +
  /// non-empty, the screen seeds the text field with this value
  /// and runs the search immediately on mount — so the user
  /// lands on results, not the idle state.
  final String? initialQuery;

  const SearchScreen({
    super.key,
    this.canPop = false,
    this.initialQuery,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  List<ProductModel> _products = [];
  bool _searching = false;
  bool _hasSearched = false;
  Timer? _debounce;

  // In-memory recent searches for this session
  final List<String> _recentSearches = [];

  static const _trendingTags = [
    'Silk',
    'Linen',
    'Cotton',
    'Wool',
    'Kurta',
    'Sherwani',
    'Blazer',
    'Wedding',
    'Chambray',
    'Khadi',
  ];

  @override
  void initState() {
    super.initState();
    // Seed the text field if we were pushed with an initial
    // query (e.g. from voice search) and run the search
    // immediately so the user lands on results.
    final seed = widget.initialQuery?.trim();
    if (seed != null && seed.isNotEmpty) {
      _searchController.text = seed;
      _commitRecent(seed);
      // Defer the search a frame so setState during initState
      // doesn't fire while the framework is still building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _search(seed);
      });
    } else {
      // Auto-focus when screen opens (idle entry).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Debounced live search as user types (300ms).
  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _products = [];
        _hasSearched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  void _commitRecent(String q) {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return;
    _recentSearches.remove(trimmed);
    _recentSearches.insert(0, trimmed);
    if (_recentSearches.length > 6) _recentSearches.removeLast();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;

    setState(() {
      _searching = true;
      _hasSearched = true;
    });

    try {
      // Escape any PostgREST "or" filter special chars (commas / parens).
      final escaped = trimmed.replaceAll(',', '').replaceAll('(', '').replaceAll(')', '');
      final lowerQuery = trimmed.toLowerCase();

      // Search products (name + description only; fabric filter done client-side below)
      List<ProductModel> products = [];
      try {
        final productData = await AppSupabase.client
            .from('products')
            .select()
            .or('name.ilike.%$escaped%,description.ilike.%$escaped%');

        products = productData.map((e) => ProductModel.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Product search error: $e');
      }

      // Extra client-side match on fabric options (text array) for all products
      try {
        final allProducts = await AppSupabase.client.from('products').select();
        final byFabric = allProducts
            .map((e) => ProductModel.fromJson(e))
            .where((p) => p.fabricOptions.any(
                  (f) => f.toLowerCase().contains(lowerQuery),
                ))
            .toList();

        // Merge without duplicates
        final existing = products.map((p) => p.id).toSet();
        for (final p in byFabric) {
          if (!existing.contains(p.id)) products.add(p);
        }
      } catch (e) {
        debugPrint('Fabric match error: $e');
      }

      if (!mounted) return;
      setState(() {
        _products = products;
        _searching = false;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() {
          _products = [];
          _searching = false;
        });
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce?.cancel();
    setState(() {
      _products = [];
      _hasSearched = false;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Search Bar Row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
              child: Row(
                children: [
                  if (widget.canPop)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.primary,
                      ),
                    )
                  else
                    const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border.withAlpha(80),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _focusNode,
                              textInputAction: TextInputAction.search,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search fabrics, kurtas, suits...',
                                hintStyle: GoogleFonts.manrope(
                                  fontSize: 14,
                                  color: AppColors.textTertiary,
                                ),
                                border: InputBorder.none,
                                isCollapsed: true,
                              ),
                              onChanged: _onQueryChanged,
                              onSubmitted: (q) {
                                _commitRecent(q);
                                _search(q);
                              },
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: _clearSearch,
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.textTertiary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Body ──
            Expanded(
              child: _searching
                  ? const Center(child: CircularProgressIndicator())
                  : _hasSearched
                      ? _buildResults()
                      : _buildIdleState(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdleState() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('RECENT SEARCHES'),
              GestureDetector(
                onTap: () => setState(_recentSearches.clear),
                child: Text(
                  'CLEAR',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches
                .map((tag) => _chip(tag, leadingIcon: Icons.history_rounded))
                .toList(),
          ),
          const SizedBox(height: 28),
        ],

        _sectionTitle('TRENDING SEARCHES'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _trendingTags
              .map((tag) =>
                  _chip(tag, leadingIcon: Icons.trending_up_rounded))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: AppColors.textTertiary.withAlpha(80),
            ),
            const SizedBox(height: 12),
            Text(
              'No results for "${_searchController.text}"',
              style: GoogleFonts.manrope(
                fontSize: 15,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different search term',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        if (_products.isNotEmpty) ...[
          _sectionTitle('PRODUCTS (${_products.length})'),
          const SizedBox(height: 8),
          ..._products.map(_productTile),
          const SizedBox(height: 24),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: AppColors.textTertiary,
      ),
    );
  }

  Widget _chip(String label, {IconData? leadingIcon}) {
    return GestureDetector(
      onTap: () {
        _searchController.text = label;
        _commitRecent(label);
        _search(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productTile(ProductModel product) {
    return InkWell(
      onTap: () => context.push('/product/${product.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.checkroom_rounded,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.formattedPrice,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.north_east_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

}
