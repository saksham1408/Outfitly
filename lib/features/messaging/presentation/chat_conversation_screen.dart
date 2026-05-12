import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/locale/money.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../data/messages_repository.dart';
import '../models/message.dart';

/// One-to-one conversation with a friend. Reached from the chat
/// list or directly via `/loop/chats/<friendId>`.
///
/// Behaviour worth calling out:
///   * **Mark-as-read on mount** — every inbound message from
///     this friend that's still `read_at IS NULL` gets flipped
///     when the screen lands. Keeps the badge honest.
///   * **Append-only scroll** — when a new message arrives via
///     Realtime, we auto-scroll the list to the bottom only if
///     the user was already pinned there. If they scrolled up
///     to read an older message, we leave them in place.
///   * **Outfit-share bubbles** — render as a tappable preview
///     card with the product image + name + price. Tapping
///     pushes the PDP at `/product/<id>`.
class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({super.key, required this.friendId});

  /// The other party. Pulled from the route path.
  final String friendId;

  @override
  State<ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final _repo = MessagesRepository.instance;
  final _composer = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _friendName = 'Friend';
  String? _friendAvatar;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _hydrateFriend();
    // Defer the mark-read so the first stream emission has a
    // chance to land — otherwise we'd be UPDATE-ing rows we
    // haven't seen yet, which is fine but wastes a query.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _repo.markConversationAsRead(widget.friendId);
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _hydrateFriend() async {
    try {
      final row = await AppSupabase.client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', widget.friendId)
          .maybeSingle();
      if (!mounted || row == null) return;
      setState(() {
        _friendName = (row['full_name'] as String?)?.trim().isEmpty ?? true
            ? 'Friend'
            : (row['full_name'] as String).trim();
        _friendAvatar = row['avatar_url'] as String?;
      });
    } catch (_) {/* leave defaults */}
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _repo.sendText(recipientId: widget.friendId, body: text);
      _composer.clear();
      // Defer the auto-scroll a frame so the stream's emission
      // has reached the list builder before we ask it to jump.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
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
    final me = AppSupabase.client.auth.currentUser?.id ?? '';

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
        titleSpacing: 0,
        title: Row(
          children: [
            _SmallAvatar(
              url: _friendAvatar,
              fallbackInitial:
                  _friendName.isNotEmpty ? _friendName[0].toUpperCase() : '?',
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _friendName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: _repo.watchConversation(widget.friendId),
                builder: (context, snap) {
                  final messages = snap.data ?? const [];
                  if (snap.connectionState == ConnectionState.waiting &&
                      messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (messages.isEmpty) {
                    return const _EmptyConversation();
                  }
                  // Newly-arrived messages while the screen is
                  // already on top of the stack — mark them
                  // read silently so the badge clears.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (messages.any(
                      (m) => m.recipientId == me && m.isUnread,
                    )) {
                      _repo.markConversationAsRead(widget.friendId);
                    }
                  });
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      final mine = m.isMine(me);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: m.kind == MessageKind.outfitShare
                              ? _OutfitShareBubble(message: m, mine: mine)
                              : _TextBubble(message: m, mine: mine),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            _Composer(
              controller: _composer,
              sending: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Bubbles
// ────────────────────────────────────────────────────────────

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.message, required this.mine});

  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.74,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine
              ? null
              : Border.all(color: AppColors.primary.withAlpha(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.body ?? '',
              style: GoogleFonts.manrope(
                fontSize: 13.5,
                color: mine ? Colors.white : AppColors.primary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _hhmm(message.createdAt),
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: mine
                    ? Colors.white.withAlpha(180)
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutfitShareBubble extends StatelessWidget {
  const _OutfitShareBubble({required this.message, required this.mine});

  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final share = message.outfitShare;
    if (share == null) return _TextBubble(message: message, mine: mine);

    return GestureDetector(
      onTap: share.productId.isEmpty
          ? null
          : () => context.push('/product/${share.productId}'),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: mine ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
            border: mine
                ? null
                : Border.all(color: AppColors.primary.withAlpha(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (share.productImage != null &&
                  share.productImage!.isNotEmpty)
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    share.productImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surfaceContainer,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.checkroom_rounded,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                )
              else
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Container(
                    color: AppColors.surfaceContainer,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.checkroom_rounded,
                      size: 36,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SHARED PIECE',
                      style: GoogleFonts.manrope(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: mine
                            ? Colors.white.withAlpha(180)
                            : AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      share.productName,
                      style: GoogleFonts.newsreader(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: mine ? Colors.white : AppColors.primary,
                        height: 1.1,
                      ),
                    ),
                    if (share.productPrice != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        Money.formatStatic(share.productPrice!),
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: mine
                              ? Colors.white
                              : AppColors.accent,
                        ),
                      ),
                    ],
                    if (message.body != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        message.body!,
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          color: mine
                              ? Colors.white.withAlpha(220)
                              : AppColors.primary,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _hhmm(message.createdAt),
                      style: GoogleFonts.manrope(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: mine
                            ? Colors.white.withAlpha(180)
                            : AppColors.textTertiary,
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

// ────────────────────────────────────────────────────────────
// Composer
// ────────────────────────────────────────────────────────────

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.primary.withAlpha(15)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: AppColors.primary,
                ),
                decoration: InputDecoration(
                  hintText: 'Send a message…',
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
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: sending ? null : onSend,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
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

class _SmallAvatar extends StatelessWidget {
  const _SmallAvatar({required this.url, required this.fallbackInitial});
  final String? url;
  final String fallbackInitial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        image: url != null && url!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(url!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: url != null && url!.isNotEmpty
          ? null
          : Center(
              child: Text(
                fallbackInitial,
                style: GoogleFonts.newsreader(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: AppColors.primary.withAlpha(70),
            ),
            const SizedBox(height: 12),
            Text(
              'Say hi',
              style: GoogleFonts.newsreader(
                fontSize: 22,
                fontStyle: FontStyle.italic,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Type a message below — or open a product and tap "Share with a friend" to send them an outfit.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _hhmm(DateTime when) {
  final local = when.toLocal();
  final h = local.hour;
  final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour12:$minute ${h < 12 ? 'AM' : 'PM'}';
}
