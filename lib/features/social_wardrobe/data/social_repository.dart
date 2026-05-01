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

  /// All friend rows where I'm the *requester* and status is still
  /// pending — drives the "you sent X requests, waiting" strip on
  /// the dashboard so the sender can see (and withdraw) their open
  /// invites without checking the DB.
  Future<List<FriendConnection>> fetchOutgoingFriendRequests() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final rawRows = await _client
          .from('friend_connections')
          .select(
            'id, requester_id, addressee_id, status, created_at, updated_at',
          )
          .eq('requester_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final rows = (rawRows as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return const [];

      final profilesById = await _fetchProfilesByIds(
        rows.map((r) => r['addressee_id'] as String).toSet(),
      );

      return rows
          .map((raw) => FriendConnection.fromRow({
                ...raw,
                if (profilesById[raw['addressee_id']] != null)
                  'addressee': profilesById[raw['addressee_id']],
              }))
          .toList(growable: false);
    } catch (e, st) {
      debugPrint(
        'SocialRepository.fetchOutgoingFriendRequests failed — $e\n$st',
      );
      return const [];
    }
  }

  /// All friend rows where I'm the addressee and status is pending —
  /// drives the "incoming friend request" badge / row in the
  /// dashboard.
  ///
  /// Note: we deliberately don't use a PostgREST embed for the
  /// requester profile here because `friend_connections.requester_id`
  /// has its FK to `auth.users(id)`, not `profiles(id)`. PostgREST
  /// can't traverse that transitive relationship for embeds, so the
  /// embed silently returns 0 rows. Instead we run two queries: fetch
  /// the connection rows, then a single bulk profiles fetch keyed by
  /// the requester ids. Two round trips, but reliable.
  Future<List<FriendConnection>> fetchIncomingFriendRequests() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final rawRows = await _client
          .from('friend_connections')
          .select(
            'id, requester_id, addressee_id, status, created_at, updated_at',
          )
          .eq('addressee_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final rows = (rawRows as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return const [];

      final profilesById = await _fetchProfilesByIds(
        rows.map((r) => r['requester_id'] as String).toSet(),
      );

      return rows
          .map((raw) => FriendConnection.fromRow({
                ...raw,
                if (profilesById[raw['requester_id']] != null)
                  'requester': profilesById[raw['requester_id']],
              }))
          .toList(growable: false);
    } catch (e, st) {
      debugPrint(
        'SocialRepository.fetchIncomingFriendRequests failed — $e\n$st',
      );
      return const [];
    }
  }

  /// Bulk-fetch a list of profiles by id. Returns a `{id → row}` map
  /// so callers can stitch the joined data back onto their parent
  /// rows without an N+1 loop. Empty / null inputs short-circuit to
  /// an empty map.
  ///
  /// Profile reads are gated by the `profiles_friends_select` policy
  /// (migration 031 + 034) — non-friends quietly drop out. Callers
  /// must tolerate missing entries (the model defaults to a
  /// "Friend"-named placeholder so the UI still renders).
  Future<Map<String, Map<String, dynamic>>> _fetchProfilesByIds(
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    try {
      final rows = await _client
          .from('profiles')
          .select('id, full_name, avatar_url')
          .inFilter('id', ids.toList());
      final map = <String, Map<String, dynamic>>{};
      for (final raw in (rows as List).cast<Map<String, dynamic>>()) {
        map[raw['id'] as String] = raw;
      }
      return map;
    } catch (e) {
      debugPrint('SocialRepository._fetchProfilesByIds failed — $e');
      return const {};
    }
  }

  // ── Borrow inbox / outbox ─────────────────────────────────

  /// Borrow rows where I'm the *owner* — the "Incoming" tab on the
  /// requests dashboard. Ordered newest first; counterparty profile
  /// + wardrobe item snapshot are stitched in client-side via the
  /// same two-phase pattern as fetchIncomingFriendRequests.
  Future<List<BorrowRequest>> fetchIncomingBorrowRequests() async {
    return _fetchBorrowRequests(
      filterColumn: 'owner_id',
      counterpartyColumn: 'borrower_id',
    );
  }

  /// Borrow rows where I'm the *borrower* — the "Outgoing" tab.
  Future<List<BorrowRequest>> fetchOutgoingBorrowRequests() async {
    return _fetchBorrowRequests(
      filterColumn: 'borrower_id',
      counterpartyColumn: 'owner_id',
    );
  }

  /// Shared backbone for the two borrow-list views. Pulls the rows
  /// matching the perspective filter, then bulk-fetches the
  /// counterparty profiles + wardrobe-item previews and stitches
  /// them onto the model in code. We deliberately avoid PostgREST
  /// embeds here — `borrow_requests.owner_id` and `borrower_id`
  /// both FK to auth.users, not profiles, so embeds silently return
  /// nothing.
  Future<List<BorrowRequest>> _fetchBorrowRequests({
    required String filterColumn,
    required String counterpartyColumn,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final rawRows = await _client
          .from('borrow_requests')
          .select(
            'id, borrower_id, owner_id, wardrobe_item_id, status, '
            'borrow_start, borrow_end, note, created_at, updated_at',
          )
          .eq(filterColumn, user.id)
          .order('created_at', ascending: false);

      final rows = (rawRows as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return const [];

      final counterIds =
          rows.map((r) => r[counterpartyColumn] as String).toSet();
      final itemIds =
          rows.map((r) => r['wardrobe_item_id'] as String).toSet();

      final profilesFuture = _fetchProfilesByIds(counterIds);
      final itemsFuture = _fetchWardrobeItemPreviewsByIds(itemIds);

      final profilesById = await profilesFuture;
      final itemsById = await itemsFuture;

      // Stash each row's joined payload under both possible alias
      // keys so the model's fromRow() resolves regardless of which
      // perspective embedded which side.
      return rows.map((raw) {
        final counter = profilesById[raw[counterpartyColumn]];
        final item = itemsById[raw['wardrobe_item_id']];
        return BorrowRequest.fromRow({
          ...raw,
          if (counter != null) 'borrower': counter,
          if (counter != null) 'owner': counter,
          if (item != null) 'wardrobe_item': item,
        });
      }).toList(growable: false);
    } catch (e, st) {
      debugPrint(
        'SocialRepository._fetchBorrowRequests($filterColumn) failed — $e\n$st',
      );
      return const [];
    }
  }

  /// Bulk-fetch the minimal `wardrobe_items` projection used by the
  /// borrow list. Friends-readable rows come back via the
  /// `wardrobe_items_friends_select` policy; rows you no longer have
  /// access to (e.g. friend revoked, item deleted) drop out
  /// silently.
  Future<Map<String, Map<String, dynamic>>>
      _fetchWardrobeItemPreviewsByIds(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    try {
      final rows = await _client
          .from('wardrobe_items')
          .select('id, image_url, category')
          .inFilter('id', ids.toList());
      final map = <String, Map<String, dynamic>>{};
      for (final raw in (rows as List).cast<Map<String, dynamic>>()) {
        map[raw['id'] as String] = raw;
      }
      return map;
    } catch (e) {
      debugPrint(
        'SocialRepository._fetchWardrobeItemPreviewsByIds failed — $e',
      );
      return const {};
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
  /// Limited to the last [limit] events across both buckets, sorted
  /// by time. Same two-phase pattern as the borrow lists — fetch
  /// rows, then a bulk profile fetch keyed by the actor ids.
  Future<List<ActivityEntry>> fetchRecentActivity({int limit = 30}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      // Two parallel raw reads.
      final borrowFuture = _client
          .from('borrow_requests')
          .select(
            'id, status, updated_at, borrower_id, owner_id, wardrobe_item_id',
          )
          .or('borrower_id.eq.${user.id},owner_id.eq.${user.id}')
          .order('updated_at', ascending: false)
          .limit(limit);
      final itemsFuture = _client
          .from('wardrobe_items')
          .select(
            'id, user_id, image_url, category, created_at',
          )
          .eq('is_shareable', true)
          .neq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      final borrowRows = (await borrowFuture as List)
          .cast<Map<String, dynamic>>();
      final itemRows =
          (await itemsFuture as List).cast<Map<String, dynamic>>();

      // Collect every user id we'll need to render the actor on each
      // entry, plus item ids for the borrow rows' previews.
      final actorIds = <String>{};
      for (final r in borrowRows) {
        actorIds.add(r['borrower_id'] as String);
        actorIds.add(r['owner_id'] as String);
      }
      for (final r in itemRows) {
        actorIds.add(r['user_id'] as String);
      }
      final borrowItemIds = borrowRows
          .map((r) => r['wardrobe_item_id'] as String)
          .toSet();

      final profilesFuture = _fetchProfilesByIds(actorIds);
      final borrowItemsFuture =
          _fetchWardrobeItemPreviewsByIds(borrowItemIds);
      final profilesById = await profilesFuture;
      final borrowItemsById = await borrowItemsFuture;

      final entries = <ActivityEntry>[];

      // Borrow-lifecycle events.
      for (final row in borrowRows) {
        final status = BorrowStatus.tryParse(row['status'] as String?);
        // Skip 'pending' here — it's already surfaced on the
        // requests dashboard.
        if (status == BorrowStatus.pending) continue;
        final stitched = <String, dynamic>{
          ...row,
          if (profilesById[row['borrower_id']] != null)
            'borrower': profilesById[row['borrower_id']],
          if (profilesById[row['owner_id']] != null)
            'owner': profilesById[row['owner_id']],
          if (borrowItemsById[row['wardrobe_item_id']] != null)
            'wardrobe_item': borrowItemsById[row['wardrobe_item_id']],
        };
        entries.add(ActivityEntry._fromBorrow(stitched, status, user.id));
      }

      // Friend-added-item events.
      for (final row in itemRows) {
        final stitched = <String, dynamic>{
          ...row,
          if (profilesById[row['user_id']] != null)
            'owner': profilesById[row['user_id']],
        };
        entries.add(ActivityEntry._fromItemAdded(stitched));
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
