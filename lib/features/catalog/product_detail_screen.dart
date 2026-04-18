import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme.dart';
import '../checkout/models/order_payload.dart';
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
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                // Build the OrderPayload from the current product so the
                // measurement flow knows what the user is buying. The same
                // payload is mutated downstream (measurements / tailor
                // booking) and handed to the Cart screen.
                final payload = OrderPayload(
                  productName: product.name,
                  price: product.basePrice,
                  fabric: product.fabricOptions.isNotEmpty
                      ? product.fabricOptions.first
                      : null,
                  imageUrl:
                      product.images.isNotEmpty ? product.images.first : null,
                );
                context.push('/measurements/decision', extra: payload);
              },
              child: const Text('Customize This'),
            ),
          ),
        ),
      ),
    );
  }
}
