import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme.dart';
import '../checkout/data/cart_repository.dart';
import '../checkout/models/order_payload.dart';
import '../wishlist/data/wishlist_repository.dart';
import 'catalog_service.dart';
import 'models/product_model.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _catalogService = CatalogService();
  ProductModel? _product;
  bool _loading = true;
  bool _addingToBag = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _catalogService.getProduct(widget.productId);
      if (!mounted) return;
      setState(() {
        _product = p;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleWishlist(ProductModel product) async {
    try {
      final nowSaved =
          await WishlistRepository.instance.toggleWishlist(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          content: Text(
            nowSaved ? 'Added to Wishlist' : 'Removed from Wishlist',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update wishlist: $e')),
      );
    }
  }

  Future<void> _addToBag(ProductModel product) async {
    if (_addingToBag) return;
    setState(() => _addingToBag = true);
    try {
      await CartRepository.instance.addToCart(
        product,
        fabric: product.fabricOptions.isNotEmpty
            ? product.fabricOptions.first
            : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Added to Bag',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  context.push('/cart');
                },
                child: Text(
                  'VIEW BAG',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.accentLight,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add to bag: $e')),
      );
    } finally {
      if (mounted) setState(() => _addingToBag = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final product = _product;
    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Product not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Image Header ──
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: AppColors.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.surfaceVariant,
                child: Center(
                  child: Icon(
                    Icons.checkroom_rounded,
                    size: 80,
                    color: AppColors.textTertiary.withAlpha(80),
                  ),
                ),
              ),
            ),
          ),

          // ── Product Info ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: AppTypography.headlineLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    product.formattedPrice,
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  if (product.description != null) ...[
                    Text(product.description!, style: AppTypography.bodyMedium),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // ── Fabrics ──
                  if (product.fabricOptions.isNotEmpty) ...[
                    Text('Available Fabrics', style: AppTypography.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: product.fabricOptions
                          .map(
                            (f) => Chip(
                              label: Text(f),
                              backgroundColor: AppColors.surfaceVariant,
                              side: BorderSide.none,
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  // ── Customize CTA ──
                  Text(
                    'Make it yours — choose fabric, collar, sleeves and more.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.base),
                  // Button replaced by the bottom-anchored
                  // Customize entry that lives in the new action
                  // bar — keeps the per-product CTA hierarchy
                  // single-source.
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      // Pinned bottom action bar — visible regardless of scroll
      // position so the conversion CTA is one tap away.
      bottomNavigationBar: _PdpActionBar(
        product: product,
        addingToBag: _addingToBag,
        onWishlistTap: () => _toggleWishlist(product),
        onAddToBagTap: () => _addToBag(product),
        onGoToBagTap: () => context.push('/cart'),
        onCustomizeTap: () {
          // Embroidery products get the full Design Studio flow so
          // the customer can attach a custom reference image; the
          // studio builds the OrderPayload itself when the user
          // reaches the measurement step. Everything else goes
          // straight to the measurement decision with a fresh
          // OrderPayload that downstream screens mutate.
          if (product.isEmbroidery) {
            context.push('/product/${product.id}/design-studio');
            return;
          }
          final payload = OrderPayload(
            productName: product.name,
            price: product.basePrice,
            fabric: product.fabricOptions.isNotEmpty
                ? product.fabricOptions.first
                : null,
            imageUrl: product.images.isNotEmpty ? product.images.first : null,
          );
          context.push('/measurements/decision', extra: payload);
        },
        onTryOnTap: () => context.push('/virtual-try-on', extra: product),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Pinned bottom action bar
// ────────────────────────────────────────────────────────────

/// The hero conversion strip at the bottom of every PDP.
///
/// Two rows stacked: a thin secondary row with Try-On +
/// Customize, and a primary row with the Wishlist heart toggle
/// + the massive "Add to Bag" CTA. Both wishlist + cart state
/// flow through their respective ValueNotifier-backed
/// repositories so a tap on the heart instantly bumps the home
/// AppBar's badge — no refresh, no manual prop drilling.
class _PdpActionBar extends StatelessWidget {
  const _PdpActionBar({
    required this.product,
    required this.addingToBag,
    required this.onWishlistTap,
    required this.onAddToBagTap,
    required this.onGoToBagTap,
    required this.onCustomizeTap,
    required this.onTryOnTap,
  });

  final ProductModel product;
  final bool addingToBag;
  final VoidCallback onWishlistTap;
  final VoidCallback onAddToBagTap;
  final VoidCallback onGoToBagTap;
  final VoidCallback onCustomizeTap;
  final VoidCallback onTryOnTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.primary.withAlpha(20),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withAlpha(20),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Secondary row — Try-On + Customize, equal-weight
            // outline buttons. Lives above the primary CTA so it
            // doesn't dominate visual weight.
            Row(
              children: [
                Expanded(
                  child: _OutlineActionButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Try-On',
                    onTap: onTryOnTap,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OutlineActionButton(
                    icon: Icons.tune_rounded,
                    label: 'Customize',
                    onTap: onCustomizeTap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Primary row — Wishlist heart + Add to Bag.
            Row(
              children: [
                _WishlistHeartButton(
                  productId: product.id,
                  onTap: onWishlistTap,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AddToBagButton(
                    productId: product.id,
                    loading: addingToBag,
                    onAddTap: onAddToBagTap,
                    onGoToBagTap: onGoToBagTap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: AppColors.primary),
        label: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(
            color: AppColors.primary.withAlpha(70),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

/// Square wishlist button that fills with red/pink when the
/// product is saved. Reads from
/// `WishlistRepository.instance.ids` so a flip from any other
/// surface (the wishlist screen, another device) repaints this
/// button instantly.
class _WishlistHeartButton extends StatelessWidget {
  const _WishlistHeartButton({required this.productId, required this.onTap});

  final String productId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: WishlistRepository.instance.ids,
      builder: (context, ids, _) {
        final saved = ids.contains(productId);
        return Material(
          color: saved
              ? const Color(0xFFFFE5EA)
              : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 56,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: saved
                      ? const Color(0xFFE53958).withAlpha(120)
                      : AppColors.primary.withAlpha(70),
                  width: 1.2,
                ),
              ),
              child: Icon(
                saved ? Icons.favorite : Icons.favorite_border,
                size: 22,
                color: saved
                    ? const Color(0xFFE53958)
                    : AppColors.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The big primary CTA. Reads from `CartRepository.instance.items`
/// so the label flips between "Add to Bag" and "Go to Bag" the
/// moment the product is saved (or removed) from any surface.
class _AddToBagButton extends StatelessWidget {
  const _AddToBagButton({
    required this.productId,
    required this.loading,
    required this.onAddTap,
    required this.onGoToBagTap,
  });

  final String productId;
  final bool loading;
  final VoidCallback onAddTap;
  final VoidCallback onGoToBagTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: CartRepository.instance.items,
      builder: (context, _, _) {
        final inBag =
            CartRepository.instance.containsProduct(productId);
        final label = inBag ? 'Go to Bag' : 'Add to Bag';
        final icon = inBag
            ? Icons.shopping_bag_rounded
            : Icons.add_shopping_cart_rounded;

        return SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: loading
                ? null
                : (inBag ? onGoToBagTap : onAddTap),
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, size: 18, color: Colors.white),
            label: Text(
              label.toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        );
      },
    );
  }
}
