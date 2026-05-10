import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/locale/money.dart';
import '../../../core/theme/theme.dart';
import '../data/cart_repository.dart';
import '../models/cart_item.dart';

/// Multi-item shopping bag — the destination for the PDP
/// "Add to Bag" CTA and the home AppBar bag icon.
///
/// Distinct from the customisation-wizard's `CartScreen`
/// (the OrderPayload-driven express-checkout that's been here
/// since the bespoke flow shipped); this one binds to
/// [CartRepository.instance.items] and renders whatever the
/// customer has saved across multiple PDP visits.
class MultiItemBagScreen extends StatelessWidget {
  const MultiItemBagScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = CartRepository.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          onPressed: () => context.pop(),
        ),
        title: ValueListenableBuilder<int>(
          valueListenable: repo.count,
          builder: (context, count, _) {
            return Text(
              count == 0 ? 'Your Bag' : 'Your Bag · $count',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            );
          },
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ValueListenableBuilder<List<CartItem>>(
          valueListenable: repo.items,
          builder: (context, items, _) {
            if (items.isEmpty) return const _EmptyBag();

            return Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: repo.refresh,
                    color: AppColors.accent,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        return _BagItemCard(item: items[i]);
                      },
                    ),
                  ),
                ),
                _BagSummary(items: items),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Bag item card
// ────────────────────────────────────────────────────────────

class _BagItemCard extends StatelessWidget {
  const _BagItemCard({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.error,
        ),
      ),
      onDismissed: (_) =>
          CartRepository.instance.removeFromCart(item.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withAlpha(15)),
        ),
        child: Row(
          children: [
            // Thumbnail.
            Container(
              width: 76,
              height: 92,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                image: item.productImage != null
                    ? DecorationImage(
                        image: NetworkImage(item.productImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: item.productImage == null
                  ? const Center(
                      child: Icon(
                        Icons.checkroom_rounded,
                        color: AppColors.textTertiary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Body.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.newsreader(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                      height: 1.15,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (item.fabric != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Fabric · ${item.fabric}',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                  if (item.size != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Size · ${item.size}',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        Money.formatStatic(item.lineTotal),
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                      const Spacer(),
                      _QuantityStepper(item: item),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final repo = CartRepository.instance;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            icon: Icons.remove_rounded,
            onTap: item.quantity > 1
                ? () => repo.updateQuantity(item.id, item.quantity - 1)
                : () => repo.removeFromCart(item.id),
          ),
          SizedBox(
            width: 26,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          _StepBtn(
            icon: Icons.add_rounded,
            onTap: () => repo.updateQuantity(item.id, item.quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 14, color: AppColors.primary),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Bag summary (sticky footer)
// ────────────────────────────────────────────────────────────

class _BagSummary extends StatelessWidget {
  const _BagSummary({required this.items});

  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    final subtotal =
        items.fold<double>(0, (sum, it) => sum + it.lineTotal);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.primary.withAlpha(20)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SUBTOTAL',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Money.formatStatic(subtotal),
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/checkout'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(
                      'CHECKOUT',
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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

// ────────────────────────────────────────────────────────────
// Empty bag
// ────────────────────────────────────────────────────────────

class _EmptyBag extends StatelessWidget {
  const _EmptyBag();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 56,
              color: AppColors.primary.withAlpha(80),
            ),
            const SizedBox(height: 16),
            Text(
              'Your bag is empty',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Browse the catalog and tap "Add to Bag" on any piece to save it for later.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => context.push('/catalog'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'BROWSE CATALOG',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
