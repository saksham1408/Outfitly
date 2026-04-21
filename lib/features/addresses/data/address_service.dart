import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/saved_address.dart';

/// Manages the user's saved delivery addresses.
///
/// v1 stores everything in SharedPreferences — good enough for a single
/// device and keeps the delivery picker working fully offline. When we
/// move this to Supabase we'll keep the same public API and only swap
/// the persistence calls.
class AddressService {
  AddressService._();
  static final AddressService instance = AddressService._();

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

  bool _loaded = false;

  /// Idempotent — safe to call from multiple screens during startup.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
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
      debugPrint('AddressService.ensureLoaded failed — $e');
    }
  }

  /// Saves a new address and makes it the currently selected one.
  Future<SavedAddress> add({
    required AddressLabel label,
    required String recipientName,
    required String pincode,
    required String city,
    required String addressLine1,
    String? addressLine2,
    required double latitude,
    required double longitude,
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
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.now(),
    );
    _addresses.value = [...(_addresses.value), created];
    _selectedId.value = created.id;
    await _persist();
    return created;
  }

  /// Marks an existing address as selected. Silently no-ops if the id
  /// isn't in the list — safer than throwing from UI callbacks.
  Future<void> select(String id) async {
    await ensureLoaded();
    final exists = _addresses.value.any((a) => a.id == id);
    if (!exists) return;
    _selectedId.value = id;
    await _persist();
  }

  /// Removes an address. If that was the selected one we either fall
  /// back to the first remaining address or clear the selection.
  Future<void> remove(String id) async {
    await ensureLoaded();
    final next = _addresses.value.where((a) => a.id != id).toList();
    _addresses.value = next;
    if (_selectedId.value == id) {
      _selectedId.value = next.isEmpty ? null : next.first.id;
    }
    await _persist();
  }

  Future<void> _persist() async {
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
      debugPrint('AddressService._persist failed — $e');
    }
  }
}
