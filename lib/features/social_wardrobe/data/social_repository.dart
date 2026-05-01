import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/supabase_client.dart';
import '../models/borrow_request.dart';
import '../models/friend_connection.dart';

/// Backend glue for the Friend Closet feature *minus* the wardrobe-
/// item reads (those stay on `WardrobeRepository` per the spec).
///
/// Surfaces:
///   * Friend graph: search by contact, send / accept / decline /
///     withdraw a friend request, list pending invites.
///   * Borrow inbox/outbox: list incoming + outgoing borrow rows,
///     change their status (approve, deny, cancel, mark returned).
///   * Activity feed: a small union of "friend added items" +
///     "borrow lifecycle events" sorted by recency. The feed is
///     read-only; nothing writes to a dedicated activity table —
///     we compute it from the existing rows.
class SocialRepository {
  SocialRepository._();
  static final SocialRepository instance = SocialRepository._();

  final _client = AppSupabase.client;

  // ── Friend search ──────────────────────────────────────────

  /// Look up a user by exact email or phone match. Calls the
  /// `find_profile_by_contact` RPC (defined in migration 032) which
  /// is SECURITY DEFINER so we can find non-friends without
  /// punching a hole in the profiles RLS.
  ///
  /// Returns null on no match, the caller's *own* profile (we filter
  /// that out server-side), or any error.
  Future<FriendProfile?> findProfileByContact(String contact) async {
    final trimmed = contact.trim();
    if (trimmed.isEmpty) return null;

    try {
      final result = await _client
          .rpc('find_profile_by_contact', params: {'contact': trimmed});
      if (result is List && result.isNotEmpty) {
        return FriendProfile.fromRow(result.first as Map<String, dynamic>);
      }
      return null;
    } catch (e, st) {
      debugPrint('SocialRepository.findProfileByContact failed — $e\n$st');
      return null;
    }
  }

  // ── Friend connections ─────────────────────────────────────

  /// Send a friend request. Status is forced to `pending` server-side
  /// by the INSERT policy; we don't pass it to keep round-trip
  /// payloads minimal.
  ///
  /// Returns the inserted [FriendConnection], or rethrows on failure
  /// (most commonly: duplicate-pair UNIQUE violation when the same
  /// pair already has a row in either direction).
  Future<FriendConnection> sendFriendRequest(String addresseeId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to send a friend request.');
    }
    if (user.id == addresseeId) {
      throw ArgumentError('You can\'t send a friend request to yourself.');
    }

    final inserted = await _client
        .from('friend_connections')
        .insert({'addressee_id': addresseeId})
        .select()
        .single();

    return FriendConnection.fromRow(inserted);
  }

  /// Move a pending invite to accepted. The RLS UPDATE policy gates
  /// this to the addressee — if the borrower (sender) calls this it
  /// silently no-ops (zero rows updated).
  Future<void> acceptFriendRequest(String connectionId) async {
    await _client
        .from('friend_connections')
        .update({'status': 'accepted'})
        .eq('id', connectionId);
  }

  /// Mark a pending invite as declined. Same RLS gating as accept.
  Future<void> declineFriendRequest(String connectionId) async {
    await _client
        .from('friend_connections')
        .update({'status': 'declined'})
        .eq('id', connectionId);
  }

  /// Withdraw a pending request (or unfriend an accepted one). Either
  /// party is allowed via the DELETE policy.
  Future<void> removeConnection(String connectionId) async {
    await _client.from('friend_connections').delete().eq('id', connectionId);
  }

  /// All friend rows where I'm the addressee and status is pending —
  /// drives the "incoming friend request" badge / row in the
  /// dashboard.
  Future<List<FriendConnection>> fetchIncomingFriendRequests() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final rows = await _client
          .from('friend_connections')
          .select(
            'id, requester_id, addressee_id, status, created_at, updated_at, '
            'requester:profiles!requester_id(id, full_name, avatar_url)',
          )
          .eq('addressee_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(FriendConnection.fromRow)
          .toList(growable: false);
    } catch (e, st) {
      debugPrint(
        'SocialRepository.fetchIncomingFriendRequests failed — $e\n$st',
      );
      return const [];
    }
  }

  // ── Borrow inbox / outbox ─────────────────────────────────

  /// Borrow rows where I'm the *owner* — the "Incoming" tab on the
  /// requests dashboard. Ordered newest first; the borrower's
  /// profile + the wardrobe item snapshot are embedded so a single
  /// fetch paints the whole list.
  Future<List<BorrowRequest>> fetchIncomingBorrowRequests() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final rows = await _client
          .from('borrow_requests')
          .select(
            'id, borrower_id, owner_id, wardrobe_item_id, status, '
            'borrow_start, borrow_end, note, created_at, updated_at, '
            'borrower:profiles!borrower_id(id, full_name, avatar_url), '
            'wardrobe_item:wardrobe_items!wardrobe_item_id(id, image_url, category)',
          )
          .eq('owner_id', user.id)
          .order('created_at', ascending: false);

      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(BorrowRequest.fromRow)
          .toList(growable: false);
    } catch (e, st) {
      debugPrint(
        'SocialRepository.fetchIncomingBorrowRequests failed — $e\n$st',
      );
      return const [];
    }
  }

  /// Borrow rows where I'm the *borrower* — the "Outgoing" tab.
  Future<List<BorrowRequest>> fetchOutgoingBorrowRequests() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final rows = await _client
          .from('borrow_requests')
          .select(
            'id, borrower_id, owner_id, wardrobe_item_id, status, '
            'borrow_start, borrow_end, note, created_at, updated_at, '
            'owner:profiles!owner_id(id, full_name, avatar_url), '
            'wardrobe_item:wardrobe_items!wardrobe_item_id(id, image_url, category)',
          )
          .eq('borrower_id', user.id)
          .order('created_at', ascending: false);

      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(BorrowRequest.fromRow)
          .toList(growable: false);
    } catch (e, st) {
      debugPrint(
        'SocialRepository.fetchOutgoingBorrowRequests failed — $e\n$st',
      );
      return const [];
    }
  }

  /// Server-side state transition for a borrow row. The valid
  /// next-state matrix is enforced in the calling widget; this
  /// method just wraps the UPDATE with an optional status filter
  /// (so we never accidentally bump a 'returned' row back to
  /// 'pending' if the UI got stale).
  Future<void> updateBorrowStatus(
    String requestId,
    BorrowStatus next, {
    BorrowStatus? expecting,
  }) async {
    if (expecting != null) {
      await _client
          .from('borrow_requests')
          .update({'status': next.wire})
          .eq('id', requestId)
          .eq('status', expecting.wire);
    } else {
      await _client
          .from('borrow_requests')
          .update({'status': next.wire})
          .eq('id', requestId);
    }
  }

  // ── Activity feed ─────────────────────────────────────────

  /// A small union of recent events relevant to the calling user:
  ///   * `friend_added_item` — a friend uploaded a new piece
  ///   * `borrow_approved` / `borrow_active` / `borrow_returned` —
  ///     lifecycle events on borrow rows where I'm a party
  ///
  /// Limited to the last 50 events across both buckets, sorted by
  /// time. Implemented client-side rather than a Postgres view
  /// because (a) the result is small, (b) it composes with RLS
  /// without a SECURITY DEFINER, and (c) the cardinality keeps it
  /// O(1) round-trips.
  Future<List<ActivityEntry>> fetchRecentActivity({int limit = 30}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      // Two parallel reads — the borrow lifecycle + recent items
      // belonging to friends. The friends-read RLS policy covers
      // the wardrobe items join automatically.
      final results = await Future.wait([
        _client
            .from('borrow_requests')
            .select(
              'id, status, updated_at, borrower_id, owner_id, '
              'borrower:profiles!borrower_id(id, full_name, avatar_url), '
              'owner:profiles!owner_id(id, full_name, avatar_url), '
              'wardrobe_item:wardrobe_items!wardrobe_item_id(id, image_url, category)',
            )
            .or('borrower_id.eq.${user.id},owner_id.eq.${user.id}')
            .order('updated_at', ascending: false)
            .limit(limit),
        // Friends' newly uploaded items — `is_shareable=true` filter
        // matches the friends-can-read RLS condition.
        _client
            .from('wardrobe_items')
            .select(
              'id, user_id, image_url, category, created_at, '
              'owner:profiles!user_id(id, full_name, avatar_url)',
            )
            .eq('is_shareable', true)
            .neq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(limit),
      ]);

      final entries = <ActivityEntry>[];

      // Borrow-lifecycle events.
      for (final row in (results[0] as List).cast<Map<String, dynamic>>()) {
        final status = BorrowStatus.tryParse(row['status'] as String?);
        // Skip the 'pending' bucket — it's already on the requests
        // dashboard with an Approve/Decline pair; surfacing it here
        // too would feel duplicative.
        if (status == BorrowStatus.pending) continue;
        entries.add(ActivityEntry._fromBorrow(row, status, user.id));
      }

      // Friend-added-item events.
      for (final row in (results[1] as List).cast<Map<String, dynamic>>()) {
        entries.add(ActivityEntry._fromItemAdded(row));
      }

      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return entries.take(limit).toList(growable: false);
    } catch (e, st) {
      debugPrint('SocialRepository.fetchRecentActivity failed — $e\n$st');
      return const [];
    }
  }
}

/// One row in the activity feed. Discriminated by [type]; the
/// rendering widget switches on it.
@immutable
class ActivityEntry {
  final ActivityType type;
  final DateTime timestamp;
  final FriendProfile actor;
  final String? itemImageUrl;
  final String? itemCategory;

  /// Free-text headline ready to render — composed when the entry is
  /// constructed so the list widget doesn't need a switch on type.
  /// (e.g. "Aisha added a Top to her closet" / "Rahul borrowed a Blazer".)
  final String headline;

  const ActivityEntry({
    required this.type,
    required this.timestamp,
    required this.actor,
    required this.headline,
    this.itemImageUrl,
    this.itemCategory,
  });

  factory ActivityEntry._fromBorrow(
    Map<String, dynamic> row,
    BorrowStatus status,
    String selfId,
  ) {
    final borrowerEmbed = row['borrower'] as Map<String, dynamic>?;
    final ownerEmbed = row['owner'] as Map<String, dynamic>?;
    final itemEmbed = row['wardrobe_item'] as Map<String, dynamic>?;

    final isMeBorrower = row['borrower_id'] == selfId;
    final actorEmbed = isMeBorrower ? ownerEmbed : borrowerEmbed;
    final actor = actorEmbed != null
        ? FriendProfile.fromRow(actorEmbed)
        : const FriendProfile(id: '?', fullName: 'Someone');

    final itemCategory = (itemEmbed?['category'] as String?) ?? 'item';
    final firstName = actor.fullName.split(' ').first;

    String headline;
    switch (status) {
      case BorrowStatus.approved:
        headline = isMeBorrower
            ? '$firstName approved your borrow request'
            : 'You approved $firstName\'s borrow request';
        break;
      case BorrowStatus.denied:
        headline = isMeBorrower
            ? '$firstName declined your borrow request'
            : 'You declined $firstName\'s borrow request';
        break;
      case BorrowStatus.active:
        headline = isMeBorrower
            ? '$firstName\'s $itemCategory is now with you'
            : '$firstName picked up your $itemCategory';
        break;
      case BorrowStatus.returned:
        headline = '$firstName returned the $itemCategory';
        break;
      case BorrowStatus.cancelled:
        headline = '$firstName cancelled the borrow';
        break;
      case BorrowStatus.pending:
        // We filter pending out before constructing — keep a defensive
        // fallback so the type checker is happy.
        headline = '$firstName sent a borrow request';
        break;
    }

    return ActivityEntry(
      type: ActivityType.borrow,
      timestamp:
          DateTime.tryParse(row['updated_at'] as String? ?? '') ??
              DateTime.now(),
      actor: actor,
      headline: headline,
      itemImageUrl: itemEmbed?['image_url'] as String?,
      itemCategory: itemCategory,
    );
  }

  factory ActivityEntry._fromItemAdded(Map<String, dynamic> row) {
    final ownerEmbed = row['owner'] as Map<String, dynamic>?;
    final actor = ownerEmbed != null
        ? FriendProfile.fromRow(ownerEmbed)
        : const FriendProfile(id: '?', fullName: 'A friend');
    final cat = (row['category'] as String?)?.toLowerCase() ?? 'item';
    final firstName = actor.fullName.split(' ').first;

    return ActivityEntry(
      type: ActivityType.itemAdded,
      timestamp:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
              DateTime.now(),
      actor: actor,
      headline: '$firstName added a new $cat to their closet',
      itemImageUrl: row['image_url'] as String?,
      itemCategory: row['category'] as String?,
    );
  }
}

enum ActivityType { itemAdded, borrow }
