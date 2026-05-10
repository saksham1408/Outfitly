import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';

/// Singleton, ValueNotifier-backed reactive wishlist state.
///
/// The legacy `WishlistService` (lib/features/wishlist/services/
/// wishlist_service.dart) is purely imperative — every call
/// hits Postgres and there's no in-memory cache, so the home
/// AppBar's heart badge couldn't subscribe to it without a
/// poll. This repository wraps the same `wishlist` table with
/// a `ValueNotifier<Set<String>>` of "currently in wishlist"
/// product ids so:
///
///   * The PDP wishlist toggle can read membership in O(1).
///   * The home AppBar heart badge updates instantly when any
///     screen flips the toggle.
///   * Realtime mutations from another device flow through.
///
/// We model the set as **product ids only** — the wishlist
/// table is keyed (user_id, item_type='product', item_id), and
/// every callsite today operates on products. If we later add
/// lookbook saves we can split the set per item_type.
class WishlistRepository {
  WishlistRepository._();
  static final WishlistRepository instance = WishlistRepository._();

  static const String _table = 'wishlist';
  static const String _itemType = 'product';

  final SupabaseClient _client = AppSupabase.client;

  final ValueNotifier<Set<String>> _ids =
      ValueNotifier<Set<String>>(<String>{});

  /// Live set of product ids the user has saved. Bind to this
  /// from the home AppBar badge, the wishlist screen, and the
  /// PDP heart toggle.
  ValueListenable<Set<String>> get ids => _ids;

  /// Convenience listener of just the count — avoids the
  /// full-set rebuild for the home badge.
  ValueListenable<int> get count => _countNotifier;
  late final ValueNotifier<int> _countNotifier = ValueNotifier<int>(0);

  bool _fetched = false;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;

  /// Idempotent first-load. Called from `main.dart` after Supabase
  /// initialises so the heart badge has the right count before the
  /// first frame paints.
  Future<void> ensureLoaded() async {
    if (_fetched) return;
    _fetched = true;
    await refresh();
    _attachRealtime();
  }

  /// Force a re-fetch from Postgres.
  Future<void> refresh() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _setIds(const <String>{});
      return;
    }
    try {
      final rows = await _client
          .from(_table)
          .select('item_id, item_type')
          .eq('user_id', user.id)
          .eq('item_type', _itemType);
      final set = <String>{
        for (final r in rows as List)
          (r as Map<String, dynamic>)['item_id'] as String,
      };
      _setIds(set);
    } catch (e, st) {
      debugPrint('WishlistRepository.refresh failed — $e\n$st');
    }
  }

  void _attachRealtime() {
    _realtimeSub?.cancel();
    final user = _client.auth.currentUser;
    if (user == null) return;
    _realtimeSub = _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .listen((rows) {
          final set = <String>{
            for (final r in rows)
              if (r['item_type'] == _itemType) r['item_id'] as String,
          };
          _setIds(set);
        });
  }

  // ── Queries ──────────────────────────────────────────────

  /// O(1) membership check used by the PDP heart icon.
  bool isInWishlist(String productId) => _ids.value.contains(productId);

  /// Drives the home AppBar heart badge. The badge widget binds to
  /// [count] directly so the int never has to round-trip through
  /// Postgres after the first load.
  int getWishlistCount() => _ids.value.length;

  // ── Mutations ────────────────────────────────────────────

  /// Flip wishlist membership for a product. Returns the new
  /// state (`true` if the product is now saved, `false` if it was
  /// just removed). Optimistic — the in-memory set updates
  /// immediately and is reverted on server error.
  Future<bool> toggleWishlist(String productId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to save items to your wishlist.');
    }

    final currentlyIn = isInWishlist(productId);
    // Optimistic flip.
    final next = {..._ids.value};
    if (currentlyIn) {
      next.remove(productId);
    } else {
      next.add(productId);
    }
    _setIds(next);

    try {
      if (currentlyIn) {
        await _client
            .from(_table)
            .delete()
            .eq('user_id', user.id)
            .eq('item_type', _itemType)
            .eq('item_id', productId);
      } else {
        // upsert so a stale tap can't violate the
        // (user_id, item_type, item_id) unique constraint.
        await _client.from(_table).upsert({
          'user_id': user.id,
          'item_type': _itemType,
          'item_id': productId,
        });
      }
      return !currentlyIn;
    } catch (e, st) {
      // Roll back the optimistic flip if the server rejected.
      debugPrint('WishlistRepository.toggleWishlist failed — $e\n$st');
      final reverted = {..._ids.value};
      if (currentlyIn) {
        reverted.add(productId);
      } else {
        reverted.remove(productId);
      }
      _setIds(reverted);
      rethrow;
    }
  }

  // ── internals ────────────────────────────────────────────

  void _setIds(Set<String> next) {
    _ids.value = next;
    _countNotifier.value = next.length;
  }
}
