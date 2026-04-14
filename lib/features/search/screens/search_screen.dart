import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../../catalog/models/product_model.dart';
import '../../lookbook/models/lookbook_item_model.dart';
import '../../lookbook/services/lookbook_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _lookbookService = LookbookService();

  List<ProductModel> _products = [];
  List<LookbookItemModel> _lookbookItems = [];
  bool _searching = false;
  bool _hasSearched = false;

  Future<void> _search(String query) async {
    if (query.trim().length < 2) return;

    setState(() {
      _searching = true;
      _hasSearched = true;
    });

    try {
      // Search products from Supabase
      final productData = await AppSupabase.client
          .from('products')
          .select()
          .or('name.ilike.%$query%,description.ilike.%$query%,fabric_options.cs.{$query}');

      // Search lookbook from Directus
      final allLookbook = await _lookbookService.getAllItems();
      final lowerQuery = query.toLowerCase();

      if (!mounted) return;
      setState(() {
        _products = productData.map((e) => ProductModel.fromJson(e)).toList();
        _lookbookItems = allLookbook
            .where((item) =>
                item.name.toLowerCase().contains(lowerQuery) ||
                (item.description?.toLowerCase().contains(lowerQuery) ?? false) ||
                (item.fabricType?.toLowerCase().contains(lowerQuery) ?? false) ||
                (item.category?.toLowerCase().contains(lowerQuery) ?? false))
            .toList();
        _searching = false;
      });
    } catch (e) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                'Search',
                style: GoogleFonts.newsreader(
                  fontSize: 28,
                  fontStyle: FontStyle.italic,
                  color: AppColors.primary,
                ),
              ),
            ),

            // ── Search Bar ──
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: _searchController,
                onSubmitted: _search,
                style: GoogleFonts.manrope(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search fabrics, products, styles...',
                  hintStyle: GoogleFonts.manrope(
                    color: AppColors.textTertiary,
                    fontSize: 15,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textTertiary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _products = [];
                              _lookbookItems = [];
                              _hasSearched = false;
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: (v) => setState(() {}),
              ),
            ),

            // ── Quick Tags ──
            if (!_hasSearched)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POPULAR SEARCHES',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Silk', 'Linen', 'Cotton', 'Wool', 'Kurta',
                        'Shirt', 'Blazer', 'Wedding',
                      ].map((tag) => _quickTag(tag)).toList(),
                    ),
                  ],
                ),
              ),

            // ── Results ──
            if (_searching)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_hasSearched)
              Expanded(
                child: (_products.isEmpty && _lookbookItems.isEmpty)
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: AppColors.textTertiary.withAlpha(80),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No results found',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          // Products
                          if (_products.isNotEmpty) ...[
                            _sectionTitle('Products (${_products.length})'),
                            ..._products.map((p) => _productTile(p)),
                            const SizedBox(height: 20),
                          ],
                          // Lookbook
                          if (_lookbookItems.isNotEmpty) ...[
                            _sectionTitle('Fabrics (${_lookbookItems.length})'),
                            ..._lookbookItems.map((l) => _lookbookTile(l)),
                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
              )
            else
              const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _quickTag(String label) {
    return GestureDetector(
      onTap: () {
        _searchController.text = label;
        _search(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withAlpha(80)),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _productTile(ProductModel product) {
    return ListTile(
      onTap: () => context.push('/product/${product.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.checkroom_rounded, color: AppColors.textTertiary),
      ),
      title: Text(
        product.name,
        style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        product.formattedPrice,
        style: GoogleFonts.manrope(fontSize: 13, color: AppColors.accent),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
    );
  }

  Widget _lookbookTile(LookbookItemModel item) {
    return ListTile(
      onTap: () => context.push('/lookbook/${item.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: item.imageUrl != null
              ? DecorationImage(
                  image: NetworkImage(item.imageUrl!),
                  fit: BoxFit.cover,
                )
              : null,
          color: AppColors.surfaceVariant,
        ),
      ),
      title: Text(
        item.name,
        style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${item.fabricType ?? ''} · ${item.formattedPrice}',
        style: GoogleFonts.manrope(fontSize: 13, color: AppColors.accent),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
    );
  }
}
