import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../../digital_wardrobe/data/wardrobe_repository.dart';
import '../../digital_wardrobe/models/wardrobe_item.dart';
import '../models/friend_connection.dart';
import 'borrow_request_sheet.dart';

/// Read-only grid of one friend's wardrobe.
///
/// Visually mirrors `DigitalClosetScreen` (same 2-col grid, same card
/// chrome) so the user feels at home — but the action surface is
/// different: tapping a card surfaces a "Request to Borrow" CTA in a
/// detail sheet rather than the personal closet's "Mix & Match" path.
///
/// Routed at `/friend-closet/:friendId`. The screen pulls the friend's
/// public profile + their shareable items in parallel; RLS quietly
/// filters out anything the requester shouldn't see.
class FriendClosetScreen extends StatefulWidget {
  const FriendClosetScreen({super.key, required this.friendId});

  final String friendId;

  @override
  State<FriendClosetScreen> createState() => _FriendClosetScreenState();
}

class _FriendClosetScreenState extends State<FriendClosetScreen> {
  FriendProfile? _profile;
  List<WardrobeItem> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Two parallel reads; either failure is non-fatal — we still
    // render whichever half we got. Profile errors fall through to
    // a "Friend's Closet" generic header. We kick both off then
    // await each separately so PostgrestTransformBuilder doesn't
    // trip up Future.wait's strict type inference.
    final profileFuture = AppSupabase.client
        .from('profiles')
        .select('id, full_name, avatar_url')
        .eq('id', widget.friendId)
        .maybeSingle();
    final itemsFuture =
        WardrobeRepository.instance.fetchFriendWardrobe(widget.friendId);

    try {
      final p = await profileFuture;
      final items = await itemsFuture;
      if (!mounted) return;
      setState(() {
        _profile =
            p is Map<String, dynamic> ? FriendProfile.fromRow(p) : null;
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName =
        (_profile?.fullName ?? 'Friend').split(' ').first;
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
        title: Row(
          children: [
            // Tiny avatar in the AppBar so the screen visually anchors
            // to whose closet you're looking at.
            if (_profile != null)
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withAlpha(15),
                  image: _profile!.avatarUrl != null &&
                          _profile!.avatarUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(_profile!.avatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: _profile!.avatarUrl == null ||
                        _profile!.avatarUrl!.isEmpty
                    ? Text(
                        _profile!.initial,
                        style: GoogleFonts.newsreader(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
            Flexible(
              child: Text(
                "$firstName's Closet",
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? _EmptyClosetState(firstName: firstName)
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, i) => _FriendItemCard(
                      item: _items[i],
                      ownerId: widget.friendId,
                      ownerFirstName: firstName,
                    ),
                  ),
      ),
    );
  }
}

/// Tappable card on the friend's grid. Tap → details sheet with the
/// "Request to Borrow" CTA. We don't long-press-to-delete here (it's
/// not your item to delete) — the gesture surface is intentionally
/// smaller than the personal closet's.
class _FriendItemCard extends StatelessWidget {
  final WardrobeItem item;
  final String ownerId;
  final String ownerFirstName;

  const _FriendItemCard({
    required this.item,
    required this.ownerId,
    required this.ownerFirstName,
  });

  Future<void> _openDetails(BuildContext context) async {
    final saved = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemDetailsSheet(
        item: item,
        ownerId: ownerId,
        ownerFirstName: ownerFirstName,
      ),
    );

    if (saved == null) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        content: Text(
          'Borrow request sent to $ownerFirstName.',
          style: GoogleFonts.manrope(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDetails(context),
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
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surface,
                  alignment: Alignment.center,
                  child: const Icon(
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
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withAlpha(140),
                      ],
                      stops: const [0.5, 1.0],
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
            // "Borrow" hint chip in the top-right — gives the user a
            // visual cue that this card has a different action than
            // the personal closet without crowding the bottom row.
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.swap_horiz_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'BORROW',
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detail sheet that pops up when a friend's item is tapped — shows
/// the photo at full width plus the "Request to Borrow" CTA. Keeping
/// the request flow two-step (preview → bottom sheet form) avoids
/// accidental sends from a misclick on the masonry grid.
class _ItemDetailsSheet extends StatelessWidget {
  const _ItemDetailsSheet({
    required this.item,
    required this.ownerId,
    required this.ownerFirstName,
  });

  final WardrobeItem item;
  final String ownerId;
  final String ownerFirstName;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle.
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1,
              child: item.imageUrl.isNotEmpty
                  ? Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.background,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    )
                  : Container(
                      color: AppColors.background,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              _MiniTag(label: item.category),
              const SizedBox(width: 6),
              _MiniTag(label: item.styleType, filled: false),
              const SizedBox(width: 6),
              _MiniTag(label: item.color, filled: false),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () async {
                final saved = await showBorrowRequestSheet(
                  context,
                  item: item,
                  ownerId: ownerId,
                  ownerFirstName: ownerFirstName,
                );
                if (saved != null && context.mounted) {
                  // Close the details sheet and bubble the saved
                  // request up so the grid can show its snackbar.
                  Navigator.of(context).pop(saved);
                }
              },
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text(
                'REQUEST TO BORROW',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
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
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyClosetState extends StatelessWidget {
  final String firstName;
  const _EmptyClosetState({required this.firstName});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 80),
      children: [
        Icon(
          Icons.checkroom_outlined,
          size: 72,
          color: AppColors.primary.withAlpha(60),
        ),
        const SizedBox(height: 16),
        Text(
          "$firstName hasn't shared anything yet",
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'When they upload pieces and toggle them as shareable, you\'ll see them here.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Mirrors the personal closet's `_MiniTag` so the visual language
/// stays identical between the two screens.
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
