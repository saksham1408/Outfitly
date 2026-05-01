import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../data/wardrobe_repository.dart';
import '../models/wardrobe_item.dart';

/// The user's Personal Digital Wardrobe — a grid of every garment
/// they've photographed.
///
/// Behaviour:
///   * Idempotent on focus: `ensureLoaded()` so the grid is populated
///     as soon as Supabase responds.
///   * "Dress Me" pill up top → opens the Daily AI Stylist.
///   * FAB → opens the upload flow.
///   * Long-press a card → delete confirmation.
class DigitalClosetScreen extends StatefulWidget {
  const DigitalClosetScreen({super.key});

  @override
  State<DigitalClosetScreen> createState() => _DigitalClosetScreenState();
}

class _DigitalClosetScreenState extends State<DigitalClosetScreen> {
  // Filter tab — `null` means "All". Category tabs mirror the four
  // CHECK constraint values from migration 022.
  String? _filter;

  @override
  void initState() {
    super.initState();
    WardrobeRepository.instance.ensureLoaded();
  }

  Future<void> _openUpload() async {
    await context.push<void>('/digital-wardrobe/upload');
    // Refresh on return — covers the edge case where the repository's
    // optimistic splice missed (e.g. rolled back on a server error).
    if (mounted) await WardrobeRepository.instance.refresh();
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
          'My Closet',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
        actions: [
          // "Loop" → the social dashboard (Friend Closet). Sits to
          // the left of Dress Me because the social loop is the more
          // recent (and viral) flow — we want the icon visible
          // without the user having to discover it via bottom nav.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: _NetworkPill(
                onTap: () => context.push('/social'),
              ),
            ),
          ),
          // Shortcut into the daily stylist for users already in the
          // closet — they usually want to try an outfit after adding.
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _DressMePill(
                onTap: () => context.push('/digital-wardrobe/stylist'),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            selected: _filter,
            onSelected: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: WardrobeRepository.instance.refresh,
              child: ValueListenableBuilder<List<WardrobeItem>>(
                valueListenable: WardrobeRepository.instance.items,
                builder: (context, items, _) {
                  final filtered = _filter == null
                      ? items
                      : items.where((i) => i.category == _filter).toList();
                  if (filtered.isEmpty) {
                    return _EmptyState(
                      hasAnyItems: items.isNotEmpty,
                      filter: _filter,
                      onAdd: _openUpload,
                    );
                  }
                  return GridView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) =>
                        _WardrobeItemCard(item: filtered[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openUpload,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_a_photo_rounded, size: 20),
        label: Text(
          'Add Item',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

/// Horizontal filter tabs: All | Top | Bottom | Shoes | Accessory.
class _FilterBar extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _FilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final tabs = <(String?, String)>[
      (null, 'All'),
      for (final c in kWardrobeCategories) (c, c),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (value, label) = tabs[i];
          final active = value == selected;
          return Material(
            color: active ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: () => onSelected(value),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: active
                        ? AppColors.primary
                        : AppColors.primary.withAlpha(35),
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WardrobeItemCard extends StatelessWidget {
  final WardrobeItem item;
  const _WardrobeItemCard({required this.item});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Remove this item?',
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        content: Text(
          'The stylist will stop considering it for your outfits.',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Remove',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await WardrobeRepository.instance.delete(item);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Could not remove: $e',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _toggleShareable(BuildContext context) async {
    final next = !item.isShareable;
    try {
      await WardrobeRepository.instance.setShareable(item, next);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
          content: Text(
            next
                ? 'Friends can now see this item.'
                : 'Hidden — friends can no longer see this.',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Couldn\'t update: $e',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _confirmDelete(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppColors.surface),
            if (item.imageUrl.isNotEmpty)
              Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => Container(
                  color: AppColors.surface,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textTertiary,
                    size: 32,
                  ),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: AppColors.surface,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary.withAlpha(120),
                      ),
                    ),
                  );
                },
              ),
            // Dark scrim at the bottom so the label stays readable
            // regardless of the photo's palette.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withAlpha(130),
                      ],
                      stops: const [0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Row(
                children: [
                  _MiniTag(label: item.category),
                  const SizedBox(width: 6),
                  _MiniTag(label: item.styleType, filled: false),
                ],
              ),
            ),
            // Top-right: shareable / private toggle. Tap to flip;
            // we colour-code state so a glance at the grid tells you
            // which pieces are visible to friends. Lock = private,
            // people = shared.
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: item.isShareable
                    ? AppColors.accent
                    : Colors.black.withAlpha(140),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _toggleShareable(context),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      item.isShareable
                          ? Icons.groups_rounded
                          : Icons.lock_outline_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final bool filled;

  const _MiniTag({required this.label, this.filled = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: filled
            ? null
            : Border.all(color: Colors.white.withAlpha(170), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: filled ? AppColors.primary : Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasAnyItems;
  final String? filter;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.hasAnyItems,
    required this.filter,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = hasAnyItems && filter != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 120),
      children: [
        Icon(
          filtered ? Icons.filter_alt_off_outlined : Icons.checkroom_outlined,
          size: 72,
          color: AppColors.primary.withAlpha(80),
        ),
        const SizedBox(height: 16),
        Text(
          filtered
              ? 'No $filter in your closet yet'
              : 'Your digital closet is empty',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          filtered
              ? 'Upload a piece or pick "All" to see everything.'
              : 'Photograph a few clothes to unlock the Daily AI Stylist.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_a_photo_rounded, size: 18),
              label: Text(
                'Add your first item',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(23),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sister pill to [_DressMePill] — opens the Friend Closet social
/// dashboard. Uses the deeper primary tone so the two pills sit
/// beside each other without competing for attention.
class _NetworkPill extends StatelessWidget {
  final VoidCallback onTap;
  const _NetworkPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'Loop',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DressMePill extends StatelessWidget {
  final VoidCallback onTap;
  const _DressMePill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'Dress Me',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
