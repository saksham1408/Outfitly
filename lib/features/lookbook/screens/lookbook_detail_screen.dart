import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../../checkout/models/order_payload.dart';
import '../models/lookbook_item_model.dart';
import '../services/lookbook_service.dart';
import '../widgets/color_dot_row.dart';

class LookbookDetailScreen extends StatefulWidget {
  final String itemId;

  const LookbookDetailScreen({super.key, required this.itemId});

  @override
  State<LookbookDetailScreen> createState() => _LookbookDetailScreenState();
}

class _LookbookDetailScreenState extends State<LookbookDetailScreen> {
  final _service = LookbookService();
  LookbookItemModel? _item;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final item = await _service.getItem(widget.itemId);
    if (!mounted) return;
    setState(() {
      _item = item;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final item = _item;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Item not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero Image ──
          SliverAppBar(
            expandedHeight: 420,
            pinned: true,
            backgroundColor: AppColors.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.imageUrl != null)
                    Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surfaceVariant,
                        child: const Center(
                          child: Icon(Icons.texture_rounded, size: 64),
                        ),
                      ),
                    )
                  else
                    Container(color: AppColors.surfaceVariant),

                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(80),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Badges
                  if (item.fabricType != null)
                    Positioned(
                      bottom: 60,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(220),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item.fabricType!.toUpperCase(),
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Content ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category
                  if (item.category != null) ...[
                    Text(
                      item.category!.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Name
                  Text(
                    item.name,
                    style: GoogleFonts.newsreader(
                      fontSize: 32,
                      fontStyle: FontStyle.italic,
                      color: AppColors.primary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(height: 2, width: 48, color: AppColors.accent),

                  const SizedBox(height: 20),

                  // Price
                  Text(
                    item.formattedPrice,
                    style: GoogleFonts.manrope(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                  Text(
                    'Starting price per meter',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Description
                  if (item.description != null) ...[
                    Text(
                      'About This Fabric',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description!,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Colors
                  if (item.colors.isNotEmpty) ...[
                    Text(
                      'AVAILABLE COLORS',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: item.colors.map((color) {
                        return Column(
                          children: [
                            ColorDotRow(
                              colors: [color],
                              dotSize: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              color,
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Craft Details
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _detailRow(Icons.straighten_rounded, 'Fabric Type',
                            item.fabricType ?? 'Premium'),
                        const Divider(height: 24),
                        _detailRow(Icons.palette_outlined, 'Colors Available',
                            '${item.colors.length} options'),
                        const Divider(height: 24),
                        _detailRow(Icons.local_shipping_outlined, 'Delivery',
                            '10–14 working days'),
                        const Divider(height: 24),
                        _detailRow(Icons.verified_outlined, 'Quality',
                            'Handpicked & Certified'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                final payload = OrderPayload(
                  productName: item.name,
                  price: item.price,
                  fabric: item.fabricType,
                  imageUrl: item.imageUrl,
                );
                context.push('/measurements/decision', extra: payload);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: AppColors.primary.withAlpha(80),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'CUSTOMIZE WITH THIS FABRIC',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppColors.textTertiary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
