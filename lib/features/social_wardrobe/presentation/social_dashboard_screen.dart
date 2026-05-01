import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../../digital_wardrobe/data/wardrobe_repository.dart';
import '../data/social_repository.dart';
import '../models/friend_connection.dart';
import 'add_friend_sheet.dart';

/// "My Network" — the social entry point for the Friend Closet
/// feature.
///
/// Layout:
///   * Top bar with title + "Add Friend" icon (opens [AddFriendSheet]).
///   * Optional incoming-requests strip: pending invites the user
///     hasn't answered yet, with inline Approve / Decline.
///   * Horizontal row of accepted friends — circular avatars; tap
///     opens that friend's closet at `/friend-closet/:friendId`.
///   * Vertical activity feed below.
///
/// The whole screen is built around three independent reads
/// (friends, incoming requests, activity feed) that we fan out in
/// parallel from `_load()` so the first paint isn't held back by
/// the slowest one.
class SocialDashboardScreen extends StatefulWidget {
  const SocialDashboardScreen({super.key});

  @override
  State<SocialDashboardScreen> createState() => _SocialDashboardScreenState();
}

class _SocialDashboardScreenState extends State<SocialDashboardScreen> {
  // Repos. Cached on the state so we don't pull `instance` on every rebuild.
  final _social = SocialRepository.instance;

  List<FriendConnection> _friends = const [];
  List<FriendConnection> _incoming = const [];
  List<ActivityEntry> _activity = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Three parallel fetches: accepted friends, pending invites
    // addressed to me, recent activity. Friends list lives on
    // WardrobeRepository per the spec ("Update the
    // WardrobeRepository with methods to: fetchFriends() ...");
    // SocialRepository covers the request lifecycle.
    final friendsFuture = WardrobeRepository.instance.fetchFriends();
    final incomingFuture = _social.fetchIncomingFriendRequests();
    final activityFuture = _social.fetchRecentActivity();

    final friends = await friendsFuture;
    final incoming = await incomingFuture;
    final activity = await activityFuture;

    if (!mounted) return;
    setState(() {
      _friends = friends;
      _incoming = incoming;
      _activity = activity;
      _loading = false;
    });
  }

  Future<void> _openAddFriend() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddFriendSheet(),
    );
    if (added == true) _load();
  }

  Future<void> _respond(
    FriendConnection invite,
    bool accept,
  ) async {
    try {
      if (accept) {
        await _social.acceptFriendRequest(invite.id);
      } else {
        await _social.declineFriendRequest(invite.id);
      }
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Couldn\'t respond: $e',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selfId = AppSupabase.client.auth.currentUser?.id ?? '';
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
          'My Network',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Borrow requests',
            icon: const Icon(
              Icons.swap_horiz_rounded,
              color: AppColors.primary,
            ),
            onPressed: () => context.push('/borrow-requests'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Add a friend',
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppColors.primary,
              ),
              onPressed: _openAddFriend,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
                children: [
                  if (_incoming.isNotEmpty)
                    _IncomingRequestsSection(
                      requests: _incoming,
                      selfId: selfId,
                      onRespond: _respond,
                    ),
                  _FriendsRow(friends: _friends, selfId: selfId),
                  const SizedBox(height: 24),
                  _ActivitySection(entries: _activity),
                ],
              ),
      ),
    );
  }
}

/// Horizontal scrollable row of accepted-friend avatars. Tapping
/// any avatar opens that friend's closet.
class _FriendsRow extends StatelessWidget {
  final List<FriendConnection> friends;
  final String selfId;

  const _FriendsRow({required this.friends, required this.selfId});

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          children: [
            Icon(
              Icons.groups_rounded,
              size: 48,
              color: AppColors.primary.withAlpha(60),
            ),
            const SizedBox(height: 8),
            Text(
              'No friends yet',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add a friend by their email or phone to start sharing closets.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: friends.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final f = friends[i];
          final profile = f.otherProfile;
          if (profile == null) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => context.push('/friend-closet/${profile.id}'),
            child: Column(
              children: [
                _Avatar(profile: profile, size: 64),
                const SizedBox(height: 6),
                SizedBox(
                  width: 70,
                  child: Text(
                    profile.fullName.split(' ').first,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
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

/// "Friend requests" strip — only renders when there's at least one
/// pending invite addressed to me.
class _IncomingRequestsSection extends StatelessWidget {
  final List<FriendConnection> requests;
  final String selfId;
  final void Function(FriendConnection, bool accept) onRespond;

  const _IncomingRequestsSection({
    required this.requests,
    required this.selfId,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${requests.length} FRIEND ${requests.length == 1 ? "REQUEST" : "REQUESTS"}',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          for (final invite in requests) _InviteRow(
            invite: invite,
            selfId: selfId,
            onRespond: onRespond,
          ),
        ],
      ),
    );
  }
}

class _InviteRow extends StatelessWidget {
  final FriendConnection invite;
  final String selfId;
  final void Function(FriendConnection, bool accept) onRespond;

  const _InviteRow({
    required this.invite,
    required this.selfId,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    final profile = invite.otherProfile;
    if (profile == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _Avatar(profile: profile, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              profile.fullName,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Decline',
            icon: const Icon(Icons.close_rounded, color: AppColors.error),
            onPressed: () => onRespond(invite, false),
          ),
          IconButton(
            tooltip: 'Accept',
            icon: const Icon(Icons.check_rounded, color: AppColors.primary),
            onPressed: () => onRespond(invite, true),
          ),
        ],
      ),
    );
  }
}

/// Vertical list of recent events. Section header + stack of
/// [ActivityCard] rows.
class _ActivitySection extends StatelessWidget {
  final List<ActivityEntry> entries;
  const _ActivitySection({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVITY',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No activity yet — add some friends and your feed will fill up.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            for (final entry in entries) _ActivityCard(entry: entry),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityEntry entry;
  const _ActivityCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withAlpha(15)),
      ),
      child: Row(
        children: [
          _Avatar(profile: entry.actor, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.headline,
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _ago(entry.timestamp),
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (entry.itemImageUrl != null && entry.itemImageUrl!.isNotEmpty) ...[
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                entry.itemImageUrl!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 44,
                  height: 44,
                  color: AppColors.surface,
                  child: const Icon(Icons.image_outlined, size: 18),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Compact "5m ago / 3h ago / 2d ago" formatter. Bigger gaps fall
  /// through to a date — feed entries older than a week are rare
  /// enough that we don't need a full DateFormat dependency here.
  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }
}

/// Circular avatar — reuses across the dashboard, friend cards,
/// invite rows, activity feed. Uses the network image when present;
/// falls back to a coloured circle with the user's initial.
class _Avatar extends StatelessWidget {
  final FriendProfile profile;
  final double size;

  const _Avatar({required this.profile, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withAlpha(15),
        border: Border.all(
          color: AppColors.primary.withAlpha(40),
          width: 1,
        ),
        image: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(profile.avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
          ? Text(
              profile.initial,
              style: GoogleFonts.newsreader(
                fontSize: size * 0.42,
                fontStyle: FontStyle.italic,
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }
}
