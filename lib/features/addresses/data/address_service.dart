import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/supabase_client.dart';
import '../models/saved_address.dart';

/// Manages the user's saved delivery addresses.
///
/// v3 reads/writes the `public.user_addresses` table in Supabase (see
/// migration `020_user_addresses.sql`) and keeps a SharedPreferences
/// mirror as an **offline cache** — nothing more. The cache gives us
/// two wins:
///
///   1. Cold launch paints the last known address list instantly, so
///      the home pill button never flashes "Set location" while the
///      network round-trip resolves.
///   2. Flights / subway rides / flaky networks don't blank out the
///      delivery sheet; we keep serving the cache until a write
///      succeeds.
///
/// Write path: Supabase first, then mirror to the cache. Selection is
/// expressed as `is_selected=true` on the row — the server trigger
/// wipes sibling selections in the same transaction, so the whole
/// operation is a single round-trip.
class AddressService {
  AddressService._();
  static final AddressService instance = AddressService._();

  static const _table = 'user_addresses';
  static const _addressesKey = 'vastrahub.addresses.v1';
  static const _selectedKey = 'vastrahub.addresses.selected.v1';

  final ValueNotifier<List<SavedAddress>> _addresses =
      ValueNotifier<List<SavedAddress>>(const []);
  final ValueNotifier<String?> _selectedId = ValueNotifier<String?>(null);

  ValueListenable<List<SavedAddress>> get addresses => _addresses;
  ValueListenable<String?> get selectedId => _selectedId;

  /// Convenience — returns the selected address object, or `null` if
  /// the id doesn't match any known address.
  SavedAddress? get selectedAddress {
    final id = _selectedId.value;
    if (id == null) return null;
    for (final a in _addresses.value) {
      if (a.id == id) return a;
    }
    return null;
  }

  bool _cacheHydrated = false;
  bool _remoteFetched = false;

  /// Idempotent two-phase load:
  ///
  ///   * phase 1: hydrate from SharedPreferences (synchronous, no
  ///     network) so any listening widget paints immediately.
  ///   * phase 2: fetch from Supabase (async) and overwrite the cache
  ///     with the authoritative list.
  ///
  /// Safe to call from multiple screens during startup — the phase
  /// flags guard against duplicate work.
  Future<void> ensureLoaded() async {
    if (!_cacheHydrated) {
      _cacheHydrated = true;
      await _hydrateFromCache();
    }
    if (!_remoteFetched) {
      _remoteFetched = true;
      // Run in the background so ensureLoaded returns as soon as the
      // cache paint is ready — callers don't need to wait on the
      // network for the first frame.
      unawaited(_fetchRemote());
    }
  }

  /// Force a refetch from Supabase — used on pull-to-refresh or after
  /// sign-in so a brand-new session sees its own rows.
  Future<void> refresh() async {
    _remoteFetched = true;
    await _fetchRemote();
  }

  Future<void> _hydrateFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_addressesKey) ?? const [];
      _addresses.value = raw
          .map((entry) {
            try {
              final decoded = jsonDecode(entry);
              if (decoded is Map<String, dynamic>) {
                return SavedAddress.fromJson(decoded);
              }
            } catch (_) {/* ignore malformed row */}
            return null;
          })
          .whereType<SavedAddress>()
          .toList(growable: false);
      _selectedId.value = prefs.getString(_selectedKey);
    } catch (e) {
      debugPrint('AddressService._hydrateFromCache failed — $e');
    }
  }

  Future<void> _fetchRemote() async {
    final userId = AppSupabase.client.auth.currentUser?.id;
    if (userId == null) {
      // No session → keep whatever cache paint we already rendered but
      // don't leak a prior user's selection id.
      _addresses.value = const [];
      _selectedId.value = null;
      await _persistCache();
      return;
    }
    try {
      final rows = await AppSupabase.client
          .from(_table)
          .select()
          .order('created_at', ascending: true);

      final list = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(SavedAddress.fromRow)
          .toList(growable: false);

      String? selected;
      for (final row in (rows).cast<Map<String, dynamic>>()) {
        if (row['is_selected'] == true) {
          selected = row['id'] as String?;
          break;
        }
      }

      _addresses.value = list;
      _selectedId.value = selected;
      await _persistCache();
    } catch (e, st) {
      debugPrint('AddressService._fetchRemote failed — $e\n$st');
      // Preserve the existing cache paint. A transient failure
      // shouldn't blank the picker sheet.
    }
  }

  /// Saves a new address and makes it the currently selected one.
  /// [latitude]/[longitude] default to 0 for manually-entered rows
  /// (the add-address form). The "Use current location" path passes
  /// real coordinates through.
  Future<SavedAddress> add({
    required AddressLabel label,
    required String recipientName,
    required String pincode,
    required String city,
    required String addressLine1,
    String? addressLine2,
    String? state,
    String? phone,
    double latitude = 0,
    double longitude = 0,
  }) async {
    await ensureLoaded();
    final created = SavedAddress(
      id: const Uuid().v4(),
      label: label,
      recipientName: recipientName,
      pincode: pincode,
      city: city,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      state: state,
      phone: phone,
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.now(),
    );

    // Persist to Supabase first. We pass `is_selected: true` so the
    // same round-trip marks this as the active address and the server
    // trigger wipes siblings — the home pill updates on the first
    // rebuild after the insert returns.
    final userId = AppSupabase.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await AppSupabase.client
            .from(_table)
            .insert(created.toRow(isSelected: true));
      } catch (e) {
        debugPrint('AddressService.add failed — $e');
        // Fall through to the local cache write so the UX still moves
        // forward; the next successful _fetchRemote will reconcile.
      }
    }

    _addresses.value = [...(_addresses.value), created];
    _selectedId.value = created.id;
    await _persistCache();
    return created;
  }

  /// Marks an existing address as selected. Silently no-ops if the id
  /// isn't in the list — safer than throwing from UI callbacks.
  ///
  /// The UPDATE fires the `enforce_single_selected_address` trigger,
  /// which clears the previous selection in the same transaction.
  Future<void> select(String id) async {
    await ensureLoaded();
    final exists = _addresses.value.any((a) => a.id == id);
    if (!exists) return;

    final userId = AppSupabase.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await AppSupabase.client
            .from(_table)
            .update({'is_selected': true}).eq('id', id);
      } catch (e) {
        debugPrint('AddressService.select failed — $e');
      }
    }

    _selectedId.value = id;
    await _persistCache();
  }

  /// Removes an address. If that was the selected one we either fall
  /// back to the first remaining address or clear the selection.
  Future<void> remove(String id) async {
    await ensureLoaded();

    final userId = AppSupabase.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await AppSupabase.client.from(_table).delete().eq('id', id);
      } catch (e) {
        debugPrint('AddressService.remove failed — $e');
      }
    }

    final next = _addresses.value.where((a) => a.id != id).toList();
    _addresses.value = next;
    if (_selectedId.value == id) {
      final fallback = next.isEmpty ? null : next.first.id;
      _selectedId.value = fallback;
      // If something fell into the "selected" slot we need the server
      // row to reflect that too — otherwise the next cold launch will
      // have no `is_selected=true` anywhere.
      if (fallback != null && userId != null) {
        try {
          await AppSupabase.client
              .from(_table)
              .update({'is_selected': true}).eq('id', fallback);
        } catch (e) {
          debugPrint('AddressService.remove fallback-select failed — $e');
        }
      }
    }
    await _persistCache();
  }

  Future<void> _persistCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _addressesKey,
        _addresses.value.map((a) => jsonEncode(a.toJson())).toList(),
      );
      final selected = _selectedId.value;
      if (selected == null) {
        await prefs.remove(_selectedKey);
      } else {
        await prefs.setString(_selectedKey, selected);
      }
    } catch (e) {
      debugPrint('AddressService._persistCache failed — $e');
    }
  }
}

