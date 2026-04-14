import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../../catalog/models/product_model.dart';
import '../../lookbook/models/lookbook_item_model.dart';
import '../../lookbook/services/lookbook_service.dart';
import '../services/wishlist_service.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final _wishlistService = WishlistService();
  final _lookbookService = LookbookService();

  List<ProductModel> _products = [];
  List<LookbookItemModel> _lookbookItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    setState(() => _loading = true);
    try {
      final wishlistItems = await _wishlistService.getWishlist();

      final productIds = wishlistItems
          .where((w) => w['item_type'] == 'product')
          .map((w) => w['item_id'] as String)
          .toList();

      final lookbookIds = wishlistItems
          .where((w) => w['item_type'] == 'lookbook')
          .map((w) => w['item_id'] as String)
          .toList();

      // Fetch products
      List<ProductModel> products = [];
      if (productIds.isNotEmpty) {
        final data = await AppSupabase.client
            .from('products')
            .select()
            .inFilter('id', productIds);
        products = data.map((e) => ProductModel.fromJson(e)).toList();
      }

      // Fetch lookbook items
      List<LookbookItemModel> lookbook = [];
      for (final id in lookbookIds) {
        final item = await _lookbookService.getItem(id);
        if (item != null) lookbook.add(item);
      }

      if (!mounted) return;
      setState(() {
        _products = products;
        _lookbookItems = lookbook;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeItem(String itemId, String itemType) async {
    await _wishlistService.removeFromWishlist(itemId, itemType);
    _loadWishlist();
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _products.isEmpty && _lookbookItems.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Wishlist',
                    style: GoogleFonts.newsreader(
                      fontSize: 28,
                      fontStyle: FontStyle.italic,
                      color: AppColors.primary,
                    ),
                  ),
                  if (!isEmpty)
                    Text(
                      '${_products.length + _lookbookItems.length} items',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Container(height: 2, width: 48, color: AppColors.accent),
            ),

            // ── Content ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_outline_rounded,
                                size: 56,
                                color: AppColors.textTertiary.withAlpha(60),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Your wishlist is empty',
                                style: GoogleFonts.newsreader(
                                  fontSize: 20,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Save products and fabrics you love',
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadWishlist,
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              if (_lookbookItems.isNotEmpty) ...[
                                _sectionTitle('FABRICS'),
                                ..._lookbookItems.map(
                                  (item) => _lookbookTile(item),
                                ),
                                const SizedBox(height: 20),
                              ],
                              if (_products.isNotEmpty) ...[
                                _sectionTitle('PRODUCTS'),
                                ..._products.map(
                                  (product) => _productTile(product),
                                ),
                              ],
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
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
    return Dismissible(
      key: Key('product-${product.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeItem(product.id, 'product'),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error.withAlpha(20),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      child: ListTile(
        onTap: () => context.push('/product/${product.id}'),
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.checkroom_rounded, color: AppColors.textTertiary),
        ),
        title: Text(
          product.name,
          style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          product.formattedPrice,
          style: GoogleFonts.manrope(fontSize: 14, color: AppColors.accent, fontWeight: FontWeight.w600),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.favorite_rounded, color: AppColors.error, size: 20),
          onPressed: () => _removeItem(product.id, 'product'),
        ),
      ),
    );
  }

  Widget _lookbookTile(LookbookItemModel item) {
    return Dismissible(
      key: Key('lookbook-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeItem(item.id, 'lookbook'),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error.withAlpha(20),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      child: ListTile(
        onTap: () => context.push('/lookbook/${item.id}'),
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        leading: Container(
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
        title: Text(
          item.name,
          style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${item.fabricType ?? ''} · ${item.formattedPrice}',
          style: GoogleFonts.manrope(fontSize: 14, color: AppColors.accent, fontWeight: FontWeight.w600),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.favorite_rounded, color: AppColors.error, size: 20),
          onPressed: () => _removeItem(item.id, 'lookbook'),
        ),
      ),
    );
  }
}
