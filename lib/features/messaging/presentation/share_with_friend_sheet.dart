import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../../catalog/models/product_model.dart';
import '../../digital_wardrobe/data/wardrobe_repository.dart';
import '../../social_wardrobe/models/friend_connection.dart';
import '../data/messages_repository.dart';

/// Bottom-sheet entry point for "share this outfit with a
/// friend." Pushed from the product detail screen's AppBar.
///
/// Flow:
///   1. Sheet opens with the user's accepted friend list,
///      newest connection first.
///   2. Tap a friend → optional comment field → "Send".
///   3. INSERT a row into `public.messages` via
///      [MessagesRepository.sendOutfitShare] with the product's
///      id/name/image/price stamped into the attachment.
///   4. Snackbar confirms; the recipient sees the outfit-share
///      card the moment Realtime fires on their side.
Future<void> showShareWithFriendSheet(
  BuildContext context, {
  required ProductModel product,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ShareWithFriendSheet(product: product),
  );
}

class _ShareWithFriendSheet extends StatefulWidget {
  const _ShareWithFriendSheet({required this.product});

  final ProductModel product;

  @override
  State<_ShareWithFriendSheet> createState() =>
      _ShareWithFriendSheetState();
}

class _ShareWithFriendSheetState extends State<_ShareWithFriendSheet> {
  final _commentCtrl = TextEditingController();
  late Future<List<FriendConnection>> _friendsFuture;

  /// Currently-selected friend (we let the user pick first,
  /// type an optional comment, then send). null = nobody
  /// picked yet — the Send button stays disabled.
  FriendConnection? _picked;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _friendsFuture = WardrobeRepository.instance.fetchFriends();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final picked = _picked;
    if (picked == null || _sending) return;
    final friendId = picked.otherProfile?.id ?? '';

    setState(() => _sending = true);
    try {
      await MessagesRepository.instance.sendOutfitShare(
        recipientId: friendId,
        product: widget.product,
        comment: _commentCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          content: Text(
            'Sent to ${(picked.otherProfile?.fullName ?? 'your friend')}',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t send: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.ios_share_rounded,
                      size: 18,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share with a friend',
                          style: GoogleFonts.newsreader(
                            fontSize: 22,
                            fontStyle: FontStyle.italic,
                            color: AppColors.primary,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: FutureBuilder<List<FriendConnection>>(
                future: _friendsFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final friends = snap.data ?? const [];
                  if (friends.isEmpty) {
                    return _NoFriendsState(
                      onClose: () => Navigator.of(context).pop(),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    itemCount: friends.length,
                    separatorBuilder: (_, _) => Divider(
                      color: AppColors.primary.withAlpha(10),
                      height: 1,
                      indent: 64,
                    ),
                    itemBuilder: (context, i) {
                      final f = friends[i];
                      final selected = _picked?.id == f.id;
                      return _FriendRow(
                        connection: f,
                        selected: selected,
                        onTap: () => setState(() => _picked = f),
                      );
                    },
                  );
                },
              ),
            ),
            if (_picked != null) ...[
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: TextField(
                  controller: _commentCtrl,
                  minLines: 1,
                  maxLines: 3,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add a note (optional)…',
                    hintStyle: GoogleFonts.manrope(
                      fontSize: 13.5,
                      color: AppColors.textTertiary,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceContainer,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (_picked == null || _sending) ? null : _send,
                  icon: _sending
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
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _picked == null
                        ? 'PICK A FRIEND TO SEND'
                        : 'SEND TO ${(_picked!.otherProfile?.fullName ?? 'FRIEND').toUpperCase()}',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor:
                        AppColors.primary.withAlpha(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.connection,
    required this.selected,
    required this.onTap,
  });

  final FriendConnection connection;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final friend = connection.otherProfile;
    final displayName = friend?.fullName ?? 'Friend';
    final avatarUrl = friend?.avatarUrl;
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
          image: avatarUrl != null && avatarUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(avatarUrl),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? null
            : Center(
                child: Text(
                  initial,
                  style: GoogleFonts.newsreader(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                  ),
                ),
              ),
      ),
      title: Text(
        displayName,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? AppColors.primary : Colors.transparent,
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.primary.withAlpha(60),
            width: 2,
          ),
        ),
        child: selected
            ? const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 14,
              )
            : null,
      ),
    );
  }
}

class _NoFriendsState extends StatelessWidget {
  const _NoFriendsState({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group_outlined,
              size: 48,
              color: AppColors.primary.withAlpha(80),
            ),
            const SizedBox(height: 12),
            Text(
              'Add a friend first',
              style: GoogleFonts.newsreader(
                fontSize: 22,
                fontStyle: FontStyle.italic,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Loop pairs you with people in your phone book — pick "Add a friend" from the Loop tab to get started.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onClose,
              child: Text(
                'OK',
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
