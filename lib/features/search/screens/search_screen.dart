import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../../catalog/models/product_model.dart';
import '../../lookbook/models/lookbook_item_model.dart';
import '../../lookbook/services/lookbook_service.dart';

class SearchScreen extends StatefulWidget {
  /// When true, the back arrow is shown (screen was pushed).
  final bool canPop;

  const SearchScreen({super.key, this.canPop = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _lookbookService = LookbookService();

  List<ProductModel> _products = [];
  List<LookbookItemModel> _lookbookItems = [];
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
    // Auto-focus when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
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
        _lookbookItems = [];
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
    if (query.trim().length < 2) return;

    setState(() {
      _searching = true;
      _hasSearched = true;
    });

    try {
      final productData = await AppSupabase.client
          .from('products')
          .select()
          .or(
            'name.ilike.%$query%,description.ilike.%$query%,fabric_options.cs.{$query}',
          );

      final allLookbook = await _lookbookService.getAllItems();
      final lowerQuery = query.toLowerCase();

      if (!mounted) return;
      setState(() {
        _products =
            productData.map((e) => ProductModel.fromJson(e)).toList();
        _lookbookItems = allLookbook
            .where((item) =>
                item.name.toLowerCase().contains(lowerQuery) ||
                (item.description?.toLowerCase().contains(lowerQuery) ??
                    false) ||
                (item.fabricType?.toLowerCase().contains(lowerQuery) ??
                    false) ||
                (item.category?.toLowerCase().contains(lowerQuery) ?? false))
            .toList();
        _searching = false;
      });
    } catch (e) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce?.cancel();
    setState(() {
      _products = [];
      _lookbookItems = [];
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

        const SizedBox(height: 32),

        _sectionTitle('QUICK LINKS'),
        const SizedBox(height: 10),
        _quickLink(
          icon: Icons.auto_stories_rounded,
          label: 'Browse the Lookbook',
          subtitle: 'Handpicked fabrics from India and the world',
          onTap: () => context.push('/lookbook'),
        ),
        const SizedBox(height: 10),
        _quickLink(
          icon: Icons.local_shipping_outlined,
          label: 'Track your orders',
          subtitle: 'Live stitching pipeline updates',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_products.isEmpty && _lookbookItems.isEmpty) {
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
        if (_lookbookItems.isNotEmpty) ...[
          _sectionTitle('FABRICS (${_lookbookItems.length})'),
          const SizedBox(height: 8),
          ..._lookbookItems.map(_lookbookTile),
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

  Widget _quickLink({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withAlpha(60)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textTertiary,
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

  Widget _lookbookTile(LookbookItemModel item) {
    return InkWell(
      onTap: () => context.push('/lookbook/${item.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: item.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(item.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: AppColors.surfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.fabricType ?? ''} · ${item.formattedPrice}',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppColors.textSecondary,
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
