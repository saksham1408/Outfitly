import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/locale/money.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../../checkout/data/cart_repository.dart';
import '../data/combo_repository.dart';
import '../models/combo_draft.dart';
import '../models/combo_set.dart';
import '../models/family_member.dart';

/// Lookbook results — the horizontal scroller of coordinated
/// combo sets matched against the caller's roster.
///
/// One PageView page per [ComboSet] from the repository. Each
/// page renders:
///
///   * Hero strip with the palette colour, the set name, the
///     marketing tagline.
///   * Per-member breakdown (every line: role label + product
///     name + per-piece price).
///   * Pricing strip with the slashed-out total, the discounted
///     price, and the savings badge.
///   * A primary "Add Full Set to Cart" button that loops through
///     the set's items and inserts an `orders` row per piece —
///     the existing tracking screen will show every piece as a
///     pending order, all stamped with the same `combo_set_id`
///     in `design_choices` so the atelier can group them.
class ComboResultsScreen extends StatefulWidget {
  const ComboResultsScreen({super.key, required this.draft});

  /// Final draft from the wizard — carries the roster, the
  /// garment-per-role map, the chosen fabric, and per-member
  /// sizes. The Lookbook reads from it both for the matching
  /// query (we still call ComboRepository per the roster) AND
  /// for the customization-summary strip at the top.
  final ComboDraft draft;

  /// Convenience getter — most lookups care about the roster
  /// list directly.
  List<FamilyMember> get roster => draft.roster;

  @override
  State<ComboResultsScreen> createState() => _ComboResultsScreenState();
}

class _ComboResultsScreenState extends State<ComboResultsScreen> {
  final _repo = ComboRepository.instance;
  final _pageController = PageController(viewportFraction: 0.92);

  List<ComboSet> _combos = const [];
  bool _loading = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _pageController.addListener(() {
      final p = _pageController.page?.round() ?? 0;
      if (p != _currentPage) {
        setState(() => _currentPage = p);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final combos = await _repo.fetchMatchingCombos(widget.roster);
    if (!mounted) return;
    setState(() {
      _combos = combos;
      _loading = false;
    });
  }

  /// Persist the entire combo as N rows in `public.cart_items` —
  /// one per item — and land the customer on the multi-item bag
  /// (`/cart`) so they can review the set and tap CHECKOUT.
  ///
  /// Earlier behaviour skipped the cart and INSERTed directly
  /// into `orders` then bounced to Home, which felt broken: the
  /// user tapped "Add Full Set to Cart" but had no way to see
  /// the cart or pay. Now the button matches its label exactly.
  ///
  /// `product_id` is synthesised as `combo:<set>:<memberIdx>` so
  /// every member's piece is its own line in the bag, with the
  /// combo discount pre-applied to `product_price` so the totals
  /// in the bag already reflect the bundled price.
  ///
  /// `fabric` + `size` columns carry the per-member customisation
  /// straight through to the cart line, so the bag UI shows the
  /// full brief without us needing a sidecar JSON column.
  Future<void> _addFullSetToCart(ComboSet set) async {
    final user = AppSupabase.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to add a combo set.')),
      );
      return;
    }

    final draft = widget.draft;
    final expanded = draft.expandedRoster;
    final fabric = draft.fabric;
    final discountFactor = 1 - set.discountPercent / 100.0;

    // Build one cart_items row per piece, walking expandedRoster
    // in step with the ComboItems (fetchMatchingCombos preserves
    // roster order). Per-member size + role label go onto the
    // cart row so the bag reads "Royal Blue Lehenga · Daughter
    // #1 · 6-8Y" — the customer never sees a wall of identical
    // line items.
    final rows = <Map<String, dynamic>>[];
    for (var memberIdx = 0; memberIdx < set.items.length; memberIdx++) {
      final item = set.items[memberIdx];
      final perItemPrice = item.price * discountFactor;
      final memberRole =
          memberIdx < expanded.length ? expanded[memberIdx] : item.role;
      final size = draft.sizeByMemberIndex[memberIdx];

      // Build a "Garment · Member · Size" composite name so the
      // bag row tells the full story without needing a sidecar
      // metadata blob. Falls back gracefully when any field is
      // missing.
      final memberLabel = memberRole.label;
      final composedName = _composeProductName(
        productName: item.productName,
        memberLabel: memberLabel,
        size: size,
      );

      rows.add({
        'user_id': user.id,
        // Synthetic id — distinct per combo + member so the same
        // user can have two copies of the same combo set in
        // their bag (a "Diwali for us" + a "Diwali for the
        // in-laws" scenario).
        'product_id': 'combo:${set.id}:$memberIdx',
        'product_name': composedName,
        'product_price': perItemPrice,
        'quantity': 1,
        if (fabric != null) 'fabric': fabric,
        if (size != null) 'size': size,
      });
    }

    try {
      await AppSupabase.client.from('cart_items').insert(rows);
      // Refresh the local cache so the home AppBar's bag badge
      // bumps immediately + the /cart screen renders the rows
      // without waiting on Realtime.
      await CartRepository.instance.refresh();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
          content: Text(
            '${set.items.length} pieces added to your bag — combo discount of '
            '${set.discountPercent.toStringAsFixed(0)}% applied.',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
      // Land on the bag so the customer can review + check out.
      // `go` (not `push`) collapses the combo wizard's nav stack
      // — the user came in for an action, not to drill back
      // through six screens.
      context.go('/cart');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Couldn\'t add the set: $e',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
    }
  }

  /// "Royal Blue Lehenga · Daughter #2 · 6-8Y" — composite
  /// display string used as the cart-line product name. Skips
  /// pieces that are null/empty so a missing size doesn't leave
  /// a dangling separator.
  String _composeProductName({
    required String productName,
    required String memberLabel,
    String? size,
  }) {
    final parts = <String>[productName, memberLabel];
    if (size != null && size.isNotEmpty) parts.add(size);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          'Matching Sets',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _combos.isEmpty
                ? const _EmptyState()
                : Column(
                    children: [
                      const SizedBox(height: 8),
                      _Lede(roster: widget.roster, count: _combos.length),
                      const SizedBox(height: 12),
                      _CustomizationStrip(draft: widget.draft),
                      const SizedBox(height: 12),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _combos.length,
                          itemBuilder: (context, i) => _LookbookCard(
                            set: _combos[i],
                            onAddToCart: () => _addFullSetToCart(_combos[i]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Page-position dots — orient the user at a glance.
                      _PageDots(
                        count: _combos.length,
                        current: _currentPage,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
      ),
    );
  }
}

/// Top-of-page lede — describes what they're looking at +
/// hints at the carousel below ("Swipe — N sets matched").
class _Lede extends StatelessWidget {
  const _Lede({required this.roster, required this.count});

  final List<FamilyMember> roster;
  final int count;

  String get _summary {
    final total =
        roster.fold<int>(0, (sum, m) => sum + m.quantity);
    return '$total ${total == 1 ? "person" : "people"} · '
        '$count coordinated ${count == 1 ? "set" : "sets"}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coordinated for your roster',
            style: GoogleFonts.newsreader(
              fontSize: 24,
              fontStyle: FontStyle.italic,
              color: AppColors.primary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _summary,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One Lookbook page — the visual + the per-member breakdown +
/// the price strip + the CTA.
class _LookbookCard extends StatelessWidget {
  const _LookbookCard({
    required this.set,
    required this.onAddToCart,
  });

  final ComboSet set;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final palette = Color(set.paletteColor);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // ── Hero ──
              // Gradient based on the set's palette colour.
              // When merch ships per-set photography this
              // becomes a NetworkImage; for now the gradient +
              // big icon carries the visual identity.
              Container(
                height: 170,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      palette,
                      Color.alphaBlend(
                        Colors.black.withAlpha(80),
                        palette,
                      ),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -16,
                      bottom: -16,
                      child: Icon(
                        Icons.checkroom_rounded,
                        size: 180,
                        color: Colors.white.withAlpha(30),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(48),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${set.items.length} ${set.items.length == 1 ? "PIECE" : "PIECES"}',
                              style: GoogleFonts.manrope(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            set.name,
                            style: GoogleFonts.newsreader(
                              fontSize: 26,
                              fontStyle: FontStyle.italic,
                              color: Colors.white,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            set.tagline,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              color: Colors.white.withAlpha(220),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Per-member breakdown ──
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  itemCount: set.items.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 18,
                    color: AppColors.primary.withAlpha(15),
                  ),
                  itemBuilder: (context, i) {
                    final item = set.items[i];
                    // For multiple kids of the same gender we
                    // append an index so the breakdown reads
                    // "Son #1", "Son #2".
                    final sameRoleCount = set.items
                        .where((x) => x.role == item.role)
                        .length;
                    final indexAmongRole = sameRoleCount == 1
                        ? null
                        : set.items
                                .take(i + 1)
                                .where((x) => x.role == item.role)
                                .length;
                    final label = indexAmongRole == null
                        ? item.role.label
                        : '${item.role.label} #$indexAmongRole';
                    return _BreakdownRow(
                      label: label,
                      productName: item.productName,
                      price: item.price,
                    );
                  },
                ),
              ),

              // ── Price strip + CTA ──
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: palette.withAlpha(15),
                  border: Border(
                    top: BorderSide(color: AppColors.primary.withAlpha(15)),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Money.formatStatic(set.discountedPrice),
                              style: GoogleFonts.newsreader(
                                fontSize: 26,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              Money.formatStatic(set.totalPrice),
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'SAVE ${set.discountPercent.toStringAsFixed(0)}%',
                            style: GoogleFonts.manrope(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: onAddToCart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_bag_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'ADD FULL SET TO CART',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.productName,
    required this.price,
  });

  final String label;
  final String productName;
  final double price;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            productName,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
        Text(
          Money.formatStatic(price),
          style: GoogleFonts.manrope(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: i == current ? 22 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == current
                  ? AppColors.primary
                  : AppColors.primary.withAlpha(50),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

/// Horizontally-scrolling chip strip showing the customization
/// choices the user made in the wizard (fabric, plus a chip per
/// role's chosen garment). Sits between the Lede and the
/// Lookbook so a user who scrolled into the results 5 minutes
/// after picking can re-orient without flipping back through
/// the wizard.
class _CustomizationStrip extends StatelessWidget {
  const _CustomizationStrip({required this.draft});

  final ComboDraft draft;

  @override
  Widget build(BuildContext context) {
    final chips = <_ChipSpec>[
      if (draft.fabric != null)
        _ChipSpec(icon: Icons.texture_rounded, label: draft.fabric!),
      for (final entry in draft.garmentByRole.entries)
        _ChipSpec(
          icon: Icons.checkroom_rounded,
          label: '${entry.key.label}: ${entry.value}',
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final chip = chips[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.primary.withAlpha(30)),
            ),
            child: Row(
              children: [
                Icon(chip.icon, size: 12, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  chip.label,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChipSpec {
  const _ChipSpec({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 80, 40, 40),
      child: Column(
        children: [
          Icon(
            Icons.checkroom_outlined,
            size: 72,
            color: AppColors.primary.withAlpha(80),
          ),
          const SizedBox(height: 18),
          Text(
            'No matching sets yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              fontSize: 22,
              fontStyle: FontStyle.italic,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your roster — the merchandising team is rolling out new family-set looks every week.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
