import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../data/notifications_repository.dart';
import '../models/app_notification.dart';

/// In-app notifications feed.
///
/// Shows every row in `public.notifications` belonging to the
/// signed-in user (RLS scopes the set), newest first. Each row:
///   * Bold left-aligned indicator stripe + accent icon if unread.
///   * Tap → mark read (server-side) + push the notification's
///     `route` if any.
///   * Swipe to dismiss → hard delete.
/// Plus a "Mark all as read" toolbar action that flips every
/// unread row in one batched UPDATE.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repo = NotificationsRepository.instance;

  Future<void> _markAllRead() async {
    await _repo.markAllAsRead();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Marked all as read.',
          style: GoogleFonts.manrope(fontSize: 13),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onTapNotification(AppNotification n) async {
    // Mark read first so the optimistic UI flip looks instant.
    if (n.isUnread) {
      await _repo.markAsRead(n.id);
    }
    if (!mounted) return;
    final route = n.route;
    if (route != null && route.isNotEmpty) {
      // The /offers screen guards against self-routing in a loop;
      // every other route is the marketing team's responsibility.
      context.push(route);
    }
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
          'Notifications',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
        actions: [
          StreamBuilder<int>(
            stream: _repo.unreadCountStream(),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;
              if (unread == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: _markAllRead,
                child: Text(
                  'Mark all read',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<AppNotification>>(
          stream: _repo.watch(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) return const _EmptyState();

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final n = items[i];
                return Dismissible(
                  key: ValueKey(n.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(35),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                  ),
                  onDismissed: (_) => _repo.delete(n.id),
                  child: _NotificationCard(
                    notification: n,
                    onTap: () => _onTapNotification(n),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Card
// ────────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(notification.kind);
    final isUnread = notification.isUnread;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnread
                  ? tone.accent.withAlpha(80)
                  : AppColors.divider,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon block — colour-coded by kind.
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.accent.withAlpha(28),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(tone.icon, size: 20, color: tone.accent),
              ),
              const SizedBox(width: 12),

              // Title + body + timestamp.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: isUnread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8, top: 4),
                            decoration: BoxDecoration(
                              color: tone.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (notification.body != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.body!,
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(notification.createdAt),
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              if (notification.route != null && notification.route!.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 6, top: 4),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  ({IconData icon, Color accent}) _toneFor(NotificationKind k) {
    switch (k) {
      case NotificationKind.promo:
        return (icon: Icons.local_offer_outlined, accent: AppColors.accent);
      case NotificationKind.borrow:
        return (icon: Icons.swap_horiz_rounded, accent: AppColors.info);
      case NotificationKind.appointment:
        return (
          icon: Icons.event_available_rounded,
          accent: AppColors.success,
        );
      case NotificationKind.pickup:
        return (
          icon: Icons.inventory_2_outlined,
          accent: AppColors.warning,
        );
      case NotificationKind.system:
        return (
          icon: Icons.notifications_active_outlined,
          accent: AppColors.primary,
        );
    }
  }
}

// ────────────────────────────────────────────────────────────
// Empty state
// ────────────────────────────────────────────────────────────

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
              Icons.notifications_off_outlined,
              size: 56,
              color: AppColors.primary.withAlpha(80),
            ),
            const SizedBox(height: 16),
            Text(
              'You\'re all caught up',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'New offers, borrow updates, and tailor visit alerts will show up here.',
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

// ────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────

/// "Just now" / "5m ago" / "3h ago" / "2d ago" / "12 Mar" —
/// short relative-time formatter. Ships with the screen
/// because intl's locale-aware formatters are 1MB+ overkill
/// for this micro-copy and we already roll our own elsewhere
/// in the app (see `formatPickupShort`).
String _timeAgo(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inSeconds < 60) return 'JUST NOW';
  if (diff.inMinutes < 60) return '${diff.inMinutes}M AGO';
  if (diff.inHours < 24) return '${diff.inHours}H AGO';
  if (diff.inDays < 7) return '${diff.inDays}D AGO';

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
  return '${local.day} ${months[local.month - 1]}'.toUpperCase();
}
