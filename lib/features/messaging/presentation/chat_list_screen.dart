import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../data/messages_repository.dart';
import '../models/message.dart';

/// Chat list — every conversation the calling user has with
/// their Loop friends, sorted by most recent activity.
///
/// Entry from the Loop / social dashboard via the new
/// "Messages" tile. Tapping a row pushes the dedicated
/// conversation screen at `/loop/chats/<friendId>`.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = MessagesRepository.instance;

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
          'Messages',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<List<ChatThread>>(
        stream: repo.watchThreads(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final threads = snap.data ?? const [];
          if (threads.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: threads.length,
            separatorBuilder: (_, _) => Divider(
              color: AppColors.primary.withAlpha(10),
              height: 1,
              indent: 76,
            ),
            itemBuilder: (context, i) => _ThreadTile(thread: threads[i]),
          );
        },
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread});
  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    final previewText = thread.lastMessage.kind == MessageKind.outfitShare
        ? '👗 Shared an outfit'
        : (thread.lastMessage.body ?? '');
    final initial = (thread.friendName.isNotEmpty
            ? thread.friendName.substring(0, 1)
            : '?')
        .toUpperCase();
    final hasUnread = thread.unreadCount > 0;

    return ListTile(
      onTap: () => context.push('/loop/chats/${thread.friendId}'),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      leading: _Avatar(
        url: thread.friendAvatarUrl,
        fallbackInitial: initial,
      ),
      title: Text(
        thread.friendName,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
      subtitle: Text(
        previewText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.manrope(
          fontSize: 12.5,
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
          color: hasUnread
              ? AppColors.primary
              : AppColors.textSecondary,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _shortTime(thread.lastMessage.createdAt),
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: hasUnread
                  ? AppColors.accent
                  : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          if (hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                thread.unreadCount > 99
                    ? '99+'
                    : '${thread.unreadCount}',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.fallbackInitial});

  final String? url;
  final String fallbackInitial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
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
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 56,
              color: AppColors.primary.withAlpha(80),
            ),
            const SizedBox(height: 14),
            Text(
              'No conversations yet',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add a friend in Loop and share an outfit, or just say hi — your chats land here.',
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

String _shortTime(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = when.toLocal();
  return '${local.day} ${months[local.month - 1]}';
}
