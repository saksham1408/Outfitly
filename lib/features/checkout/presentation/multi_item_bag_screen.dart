import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/locale/money.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../../combos/models/combo_catalog.dart';
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
class MultiItemBagScreen extends StatefulWidget {
  const MultiItemBagScreen({super.key});

  @override
  State<MultiItemBagScreen> createState() => _MultiItemBagScreenState();
}

class _MultiItemBagScreenState extends State<MultiItemBagScreen> {
  /// True while the CHECKOUT round-trip (orders insert + cart
  /// wipe + routing decision) is in flight. Disables the CTA so
  /// double-taps can't create duplicate order rows.
  bool _placing = false;

  /// CHECKOUT handler.
  ///
  /// The bag carries items added from two paths:
  ///   * **Combo flow** — every cart row already has a `size`
  ///     because the wizard's size step is mandatory. The size
  ///     might be a chart label ("S", "L"), a manual-
  ///     measurements blob, or the sentinel "Home Tailor Visit"
  ///     if the customer booked a home visit mid-wizard.
  ///   * **PDP "Add to Bag"** — the row may have no size set
  ///     yet (single-item bespoke flow defers measurement to
  ///     checkout).
  ///
  /// Strategy:
  ///   * If every item already has a non-empty `size`, we have
  ///     everything we need to place the order. Insert rows
  ///     into `public.orders`, clear the bag, and route the
  ///     customer to the live tailor-visit tracker (if they
  ///     booked one) or `/orders`.
  ///   * Otherwise fall back to the existing
  ///     `/measurements/decision` flow so the customer picks
  ///     how they want to be measured.
  Future<void> _handleCheckout() async {
    if (_placing) return;

    final items = CartRepository.instance.items.value;
    if (items.isEmpty) return;

    final allHaveSize =
        items.every((it) => (it.size ?? '').trim().isNotEmpty);
    if (!allHaveSize) {
      // At least one bag row needs measurements — defer to the
      // existing decision screen as before.
      context.push('/measurements/decision');
      return;
    }

    final hasHomeTailorVisit = items.any(
      (it) => isTailorVisitSize(it.size),
    );

    setState(() => _placing = true);
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) {
        throw StateError('Sign in to place an order.');
      }

      // Estimated delivery: a fortnight from now is the
      // conservative default the atelier publishes. Stored on
      // the `orders.estimated_delivery` column (date, not
      // timestamp).
      final estimatedDelivery = DateTime.now()
          .add(const Duration(days: 14))
          .toIso8601String()
          .split('T')
          .first;

      // Track the combo grouping as we walk the rows. If every
      // placed order belongs to the SAME combo set, we route the
      // customer to the dedicated combo-tracking screen at the
      // end (couple → 2 trackers, family → 1 combined view).
      String? sharedComboSetId;
      var allSameCombo = true;

      final rows = <Map<String, dynamic>>[];
      for (final it in items) {
        final comboMeta = _parseComboProductId(it.productId);
        if (comboMeta == null) {
          allSameCombo = false;
        } else {
          if (sharedComboSetId == null) {
            sharedComboSetId = comboMeta.setId;
          } else if (sharedComboSetId != comboMeta.setId) {
            allSameCombo = false;
          }
        }

        rows.add({
          'user_id': user.id,
          'product_name': it.productName,
          if (it.fabric != null) 'fabric': it.fabric,
          'total_price': it.lineTotal,
          // 'order_placed' is the very first status in the
          // pipeline check from migration 008.
          'status': 'order_placed',
          'estimated_delivery': estimatedDelivery,
          'design_choices': <String, dynamic>{
            if (it.fabric != null) 'fabric': it.fabric,
            if (it.size != null) 'size': it.size,
            'quantity': it.quantity,
            'unit_price': it.productPrice,
            if (comboMeta != null) ...{
              'combo_set_id': comboMeta.setId,
              'combo_member_idx': comboMeta.memberIdx,
              'role': comboMeta.roleName,
            },
          },
          'tracking_note': isTailorVisitSize(it.size)
              ? 'Measurements via tailor home-visit.'
              : (isManualSize(it.size)
                  ? 'Self-reported measurements at checkout.'
                  : 'Standard chart size.'),
        });
      }

      await AppSupabase.client.from('orders').insert(rows);
      await CartRepository.instance.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
          content: Text(
            '${items.length} order${items.length == 1 ? '' : 's'} placed — '
            'we\'ll keep you posted as each piece moves through the pipeline.',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );

      // Route decision priority:
      //   1. Combo flow → dedicated combo tracker (couple shows
      //      two side-by-side timelines, family shows one
      //      combined view). This wins over the tailor-visit
      //      tracker because the combo screen already embeds
      //      the visit status inline.
      //   2. Home-tailor booking with no combo grouping → live
      //      tailor-visit tracker.
      //   3. Everything else → standard /orders list.
      String? aptId;
      if (hasHomeTailorVisit && !(allSameCombo && sharedComboSetId != null)) {
        aptId = await _findActiveAppointmentId(user.id);
      }
      if (!mounted) return;
      if (allSameCombo && sharedComboSetId != null) {
        context.go('/combos/tracking/$sharedComboSetId');
      } else if (aptId != null) {
        context.go('/tailor-visit/$aptId');
      } else {
        context.go('/orders');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Couldn\'t place order: $e',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  /// Parse a `combo:<setId>:<idx>:<role>` synthetic product_id
  /// back into its parts. Returns null for any non-combo product
  /// (regular PDP "Add to Bag" rows). Lenient on the trailing
  /// `:<role>` so legacy rows from before the role-encoding
  /// change still parse cleanly (role falls back to empty).
  _ComboCartMeta? _parseComboProductId(String? productId) {
    if (productId == null || !productId.startsWith('combo:')) return null;
    final parts = productId.split(':');
    if (parts.length < 3) return null;
    final setId = parts[1];
    final idx = int.tryParse(parts[2]) ?? 0;
    final role = parts.length >= 4 ? parts[3] : '';
    if (setId.isEmpty) return null;
    return _ComboCartMeta(setId: setId, memberIdx: idx, roleName: role);
  }

  /// Look up the user's most recent in-flight tailor visit so we
  /// can route them to its live tracker after checkout. "In
  /// flight" = any status that isn't `completed` or `cancelled`.
  /// Returns null when there's nothing to show, in which case
  /// the caller falls back to `/orders`.
  Future<String?> _findActiveAppointmentId(String userId) async {
    try {
      final row = await AppSupabase.client
          .from('tailor_appointments')
          .select('id')
          .eq('user_id', userId)
          .inFilter('status', const [
            'pending',
            'pending_tailor_approval',
            'accepted',
            'en_route',
            'arrived',
          ])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row?['id']?.toString();
    } catch (_) {
      return null;
    }
  }

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
                _BagSummary(
                  items: items,
                  placing: _placing,
                  onCheckoutTap: _handleCheckout,
                ),
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

/// Parsed shape of a combo cart row's synthetic product_id.
/// Carried into `orders.design_choices` so the combo-tracking
/// screen can group rows by role + set without parsing again.
class _ComboCartMeta {
  const _ComboCartMeta({
    required this.setId,
    required this.memberIdx,
    required this.roleName,
  });

  final String setId;
  final int memberIdx;
  final String roleName;
}

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
  const _BagSummary({
    required this.items,
    required this.placing,
    required this.onCheckoutTap,
  });

  final List<CartItem> items;

  /// True while the parent screen is busy placing the orders.
  /// Disables + spinnerises the CHECKOUT button.
  final bool placing;

  /// Callback the parent state owns — covers the full checkout
  /// pipeline (orders insert, cart clear, tracker routing).
  final VoidCallback onCheckoutTap;

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
                    // CHECKOUT delegates to `_handleCheckout`,
                    // which:
                    //   * places the orders straight away when
                    //     every cart row already has a `size`
                    //     (combo flow, or any flow where the
                    //     customer picked Home Tailor / Manual
                    //     measurements earlier), and routes to
                    //     the live tailor-visit tracker if a
                    //     visit was booked;
                    //   * falls back to the legacy measurements
                    //     decision screen when at least one row
                    //     hasn't been measured yet.
                    onPressed: placing ? null : onCheckoutTap,
                    icon: placing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                    label: Text(
                      placing ? 'PLACING…' : 'CHECKOUT',
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
