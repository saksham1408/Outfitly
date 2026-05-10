import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../../catalog/models/product_model.dart';
import '../data/wishlist_repository.dart';

/// Wishlist feed.
///
/// Bound to [WishlistRepository.instance.ids] — every mutation
/// (a heart-tap on the PDP, a swipe-to-dismiss here, or a flip
/// from another device via Realtime) triggers a single rebuild
/// and a refetch of any product rows we don't have cached yet.
///
/// Doesn't keep a private list — the repository is the single
/// source of truth, the screen just maps ids → products for
/// rendering.
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  /// Cache of `productId → ProductModel` so we don't re-hit
  /// Postgres on every wishlist mutation. Populated lazily —
  /// when the listener fires for an id we haven't seen yet, we
  /// fetch and stash.
  final Map<String, ProductModel> _productCache = {};

  Set<String>? _lastIds;

  @override
  void initState() {
    super.initState();
    // Force a refresh so a cold-launched screen sees the latest
    // wishlist before the listener fires.
    WishlistRepository.instance.ensureLoaded();
    WishlistRepository.instance.ids.addListener(_onIdsChanged);
    _onIdsChanged();
  }

  @override
  void dispose() {
    WishlistRepository.instance.ids.removeListener(_onIdsChanged);
    super.dispose();
  }

  Future<void> _onIdsChanged() async {
    final ids = WishlistRepository.instance.ids.value;
    if (_lastIds != null && _setsEqual(_lastIds!, ids)) return;
    _lastIds = Set.of(ids);

    final missing = ids.where((id) => !_productCache.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      try {
        final rows = await AppSupabase.client
            .from('products')
            .select()
            .inFilter('id', missing);
        for (final raw in (rows as List).cast<Map<String, dynamic>>()) {
          final p = ProductModel.fromJson(raw);
          _productCache[p.id] = p;
        }
      } catch (_) {/* best-effort */}
    }
    if (mounted) setState(() {});
  }

  bool _setsEqual(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final v in a) {
      if (!b.contains(v)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final ids = WishlistRepository.instance.ids.value;
    // Keep the order stable by sorting ids; new arrivals push to
    // the bottom this way. (We could also order by `created_at`
    // server-side, but that needs another column on the cache.)
    final products = ids
        .map((id) => _productCache[id])
        .whereType<ProductModel>()
        .toList(growable: false);
    final isEmpty = ids.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header.
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
                      '${ids.length} items',
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

            // Content.
            Expanded(
              child: isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      onRefresh: WishlistRepository.instance.refresh,
                      color: AppColors.accent,
                      child: ListView(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          _sectionTitle('PRODUCTS'),
                          ...products.map(_productTile),
                          // Render placeholder rows for ids whose
                          // product hasn't been cached yet — keeps
                          // the count honest while we fetch.
                          if (products.length < ids.length)
                            ...List.generate(
                              ids.length - products.length,
                              (_) => _loadingTile(),
                            ),
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

  Widget _emptyState() {
    return Center(
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
            'Tap the heart on any product to save it here.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
        ],
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
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _productTile(ProductModel product) {
    return Dismissible(
      key: Key('product-${product.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) =>
          WishlistRepository.instance.toggleWishlist(product.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
        ),
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
          child: const Icon(
            Icons.checkroom_rounded,
            color: AppColors.textTertiary,
          ),
        ),
        title: Text(
          product.name,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          product.formattedPrice,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.favorite_rounded,
            color: Color(0xFFE53958),
            size: 20,
          ),
          onPressed: () =>
              WishlistRepository.instance.toggleWishlist(product.id),
        ),
      ),
    );
  }

  Widget _loadingTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: SizedBox(
              height: 14,
            ),
          ),
        ],
      ),
    );
  }
}
