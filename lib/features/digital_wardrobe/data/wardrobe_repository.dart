import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/supabase_client.dart';
import '../../social_wardrobe/models/borrow_request.dart';
import '../../social_wardrobe/models/friend_connection.dart';
import '../models/wardrobe_item.dart';

/// Supabase-backed store of the user's Personal Digital Wardrobe.
///
/// Every item has two halves:
///   1. A binary in the `user_wardrobe` Storage bucket, scoped to
///      `${auth.uid()}/${uuid}.jpg` so Storage RLS can key on the
///      folder name.
///   2. A row in `public.wardrobe_items` pointing at that binary,
///      guarded by own-row RLS.
///
/// The repository is a ValueNotifier-backed singleton so the closet
/// grid, the upload screen, and the AI stylist all rebuild in lockstep
/// when the list changes — without dragging in a state-management
/// library for a single feature.
class WardrobeRepository {
  WardrobeRepository._();
  static final WardrobeRepository instance = WardrobeRepository._();

  static const String _table = 'wardrobe_items';
  static const String _bucket = 'user_wardrobe';

  final _client = AppSupabase.client;

  final ValueNotifier<List<WardrobeItem>> _items =
      ValueNotifier<List<WardrobeItem>>(const <WardrobeItem>[]);
  ValueListenable<List<WardrobeItem>> get items => _items;

  bool _fetched = false;

  /// Idempotent first-load — called from the closet screen so the grid
  /// paints as soon as the network responds. Preserves the cached list
  /// on transient errors so a flaky connection doesn't blank the UI.
  Future<void> ensureLoaded() async {
    if (_fetched) return;
    _fetched = true;
    await refresh();
  }

  /// Force a refetch — used after a successful upload so the new card
  /// appears without waiting for the screen to be rebuilt.
  Future<void> refresh() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      _items.value = const [];
      return;
    }
    try {
      final rows = await _client
          .from(_table)
          .select()
          .order('created_at', ascending: false);
      _items.value = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(WardrobeItem.fromRow)
          .toList(growable: false);
    } catch (e, st) {
      debugPrint('WardrobeRepository.refresh failed — $e\n$st');
      // Preserve whatever list we already had. A transient failure
      // shouldn't empty the closet.
    }
  }

  /// Upload a clothing photo to Storage and insert the metadata row.
  ///
  /// Flow:
  ///   1. Read the [image] bytes.
  ///   2. Upload to `user_wardrobe/${uid}/${newId}.${ext}` — the
  ///      folder is the caller's uid so Storage RLS passes.
  ///   3. Grab the public URL from Storage.
  ///   4. Insert the row (server fills user_id from auth.uid()).
  ///   5. Optimistically splice the new item into the cache so the
  ///      closet grid updates on the next rebuild.
  ///
  /// Returns the created [WardrobeItem] so the upload screen can pop
  /// and the daily stylist can immediately consider the new piece.
  Future<WardrobeItem> uploadWardrobeItem({
    required File image,
    required String category,
    required String color,
    required String styleType,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to add clothes to your closet.');
    }

    final bytes = await image.readAsBytes();
    final ext = _extractExtension(image.path);
    final id = const Uuid().v4();
    // `${uid}/${id}.${ext}` — the first path segment has to be the uid
    // to satisfy the Storage INSERT policy defined in migration 022.
    final storagePath = '${user.id}/$id.$ext';

    final storage = _client.storage.from(_bucket);

    await storage.uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(
        contentType: _mimeFor(ext),
        upsert: false,
      ),
    );

    final imageUrl = storage.getPublicUrl(storagePath);

    final item = WardrobeItem(
      id: id,
      imageUrl: imageUrl,
      category: category,
      color: color,
      styleType: styleType,
      createdAt: DateTime.now(),
    );

    try {
      await _client.from(_table).insert(item.toRow());
    } catch (e) {
      // Roll back the Storage object so we don't leave orphaned
      // binaries paying for a row that never existed.
      debugPrint('WardrobeRepository.uploadWardrobeItem: row insert failed '
          '— rolling back storage: $e');
      try {
        await storage.remove([storagePath]);
      } catch (_) {/* best-effort cleanup */}
      rethrow;
    }

    _items.value = [item, ..._items.value];
    return item;
  }

  /// Flip the `is_shareable` flag on a single wardrobe item.
  ///
  /// Updates the Postgres row first so the friends-can-read RLS
  /// policy reflects the new state immediately (a friend who's mid-
  /// browse will lose the row on their next refresh). The cached
  /// list is then patched in-place via copyWith so the closet grid
  /// rebuilds without a full refetch.
  ///
  /// RLS gates the UPDATE to the owning user; if a non-owner sneaks
  /// the call in, Postgres silently does nothing and the optimistic
  /// cache flip is reverted on the next refresh.
  Future<WardrobeItem> setShareable(
    WardrobeItem item,
    bool isShareable,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to update an item.');
    }
    await _client
        .from(_table)
        .update({'is_shareable': isShareable})
        .eq('id', item.id);

    final updated = item.copyWith(isShareable: isShareable);
    _items.value = _items.value
        .map((i) => i.id == item.id ? updated : i)
        .toList(growable: false);
    return updated;
  }

  /// Remove a wardrobe item. Deletes the Postgres row first (so RLS
  /// can reject the call before we touch Storage) then the binary.
  Future<void> delete(WardrobeItem item) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from(_table).delete().eq('id', item.id);
    } catch (e) {
      debugPrint('WardrobeRepository.delete row failed — $e');
      rethrow;
    }

    // Extract the storage path from the public URL. Public URL format:
    // `.../storage/v1/object/public/user_wardrobe/<uid>/<file>`
    final storagePath = _pathFromPublicUrl(item.imageUrl);
    if (storagePath != null) {
      try {
        await _client.storage.from(_bucket).remove([storagePath]);
      } catch (e) {
        debugPrint('WardrobeRepository.delete storage cleanup failed — $e');
      }
    }

    _items.value = _items.value.where((i) => i.id != item.id).toList();
  }

  // ── Social: friends, friend closet, borrow request ──────────

  /// Fetch the calling user's accepted friends, with the *other*
  /// party's basic profile stitched in client-side.
  ///
  /// Two-phase: pull friend_connections rows, then a single bulk
  /// `profiles` fetch keyed by every "other" user id. We avoid
  /// PostgREST embeds because `friend_connections.requester_id` /
  /// `addressee_id` both FK to `auth.users`, not `profiles`, so
  /// embeds silently return zero rows.
  Future<List<FriendConnection>> fetchFriends() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final rawRows = await _client
          .from('friend_connections')
          .select(
            'id, requester_id, addressee_id, status, created_at, updated_at',
          )
          .eq('status', 'accepted')
          .order('updated_at', ascending: false);

      final rows = (rawRows as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return const [];

      // Collect "the other party" id for each row.
      final myId = user.id;
      final otherIds = rows.map((r) {
        return (r['requester_id'] == myId
            ? r['addressee_id']
            : r['requester_id']) as String;
      }).toSet();

      final profileRows = await _client
          .from('profiles')
          .select('id, full_name, avatar_url')
          .inFilter('id', otherIds.toList());

      final profilesById = <String, Map<String, dynamic>>{};
      for (final raw in (profileRows as List).cast<Map<String, dynamic>>()) {
        profilesById[raw['id'] as String] = raw;
      }

      return rows.map((raw) {
        final isMeRequester = raw['requester_id'] == myId;
        final otherId = isMeRequester
            ? raw['addressee_id'] as String
            : raw['requester_id'] as String;
        // Stash the "other" profile under the `addressee` alias the
        // model already understands, regardless of who sent the
        // original request.
        return FriendConnection.fromRow({
          ...raw,
          if (profilesById[otherId] != null)
            'addressee': profilesById[otherId],
        });
      }).toList(growable: false);
    } catch (e, st) {
      debugPrint('WardrobeRepository.fetchFriends failed — $e\n$st');
      return const [];
    }
  }

  /// Read every `is_shareable=true` wardrobe item belonging to a
  /// connected friend. The RLS policy `wardrobe_items_friends_select`
  /// enforces the friendship; if the caller passes a non-friend's id
  /// this just returns an empty list (Postgres filters us out).
  ///
  /// We populate `userId` on each model so the borrow flow has the
  /// owner id without an extra round-trip.
  Future<List<WardrobeItem>> fetchFriendWardrobe(String friendId) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('user_id', friendId)
          .eq('is_shareable', true)
          .order('created_at', ascending: false);

      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(WardrobeItem.fromRow)
          .toList(growable: false);
    } catch (e, st) {
      debugPrint(
        'WardrobeRepository.fetchFriendWardrobe($friendId) failed — $e\n$st',
      );
      return const [];
    }
  }

  /// Send a borrow request. Returns the persisted [BorrowRequest]
  /// (with server-issued id and timestamps) so the caller can splice
  /// it into the outgoing list optimistically.
  ///
  /// The call relies on RLS for safety: the
  /// `borrow_requests_borrower_insert` policy in migration 033
  /// asserts (a) the caller is a friend of the owner, (b) the item
  /// belongs to the owner, and (c) the item is `is_shareable=true`.
  /// If any of those fail the row insert throws and we surface it.
  Future<BorrowRequest> sendBorrowRequest(BorrowRequest request) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to request a borrow.');
    }

    final inserted = await _client
        .from('borrow_requests')
        .insert(request.toInsertRow())
        .select()
        .single();

    return BorrowRequest.fromRow(inserted);
  }

  // ── helpers ─────────────────────────────────────────────────

  /// Accepts either an `XFile` (from `ImagePicker`) or a raw dart:io
  /// [File] — ergonomic for the upload screen which pulls either.
  Future<WardrobeItem> uploadFromXFile({
    required XFile file,
    required String category,
    required String color,
    required String styleType,
  }) =>
      uploadWardrobeItem(
        image: File(file.path),
        category: category,
        color: color,
        styleType: styleType,
      );

  String _extractExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return 'jpg';
    return fileName.substring(dot + 1).toLowerCase();
  }

  String _mimeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }

  /// Extracts the object path from a Supabase public storage URL:
  /// `.../storage/v1/object/public/user_wardrobe/UID/FILE.jpg` → `UID/FILE.jpg`.
  String? _pathFromPublicUrl(String url) {
    final marker = '/$_bucket/';
    final idx = url.indexOf(marker);
    if (idx == -1) return null;
    return url.substring(idx + marker.length);
  }
}
