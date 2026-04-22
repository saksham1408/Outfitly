import 'package:flutter/foundation.dart';

/// Discriminator for the small "HOME / WORK / OTHER" badge we show next
/// to each saved address. Kept as an enum so the UI can't render a
/// typo'd label.
enum AddressLabel { home, work, other }

extension AddressLabelX on AddressLabel {
  /// Uppercase tag form — used in small badge pills.
  String get displayLabel => switch (this) {
        AddressLabel.home => 'HOME',
        AddressLabel.work => 'WORK',
        AddressLabel.other => 'OTHER',
      };

  /// Title-case form — used inline in the home pill button.
  String get titleCase => switch (this) {
        AddressLabel.home => 'Home',
        AddressLabel.work => 'Work',
        AddressLabel.other => 'Other',
      };

  String get storageValue => name; // home / work / other

  static AddressLabel fromStorage(String? raw) {
    switch (raw) {
      case 'home':
        return AddressLabel.home;
      case 'work':
        return AddressLabel.work;
      default:
        return AddressLabel.other;
    }
  }
}

/// A delivery address the user has saved. Purely client-side for v1 —
/// persisted to SharedPreferences via [AddressService]. When we later
/// move this to Supabase the JSON shape here is already close enough to
/// a row to make the migration painless.
///
/// The structured fields ([state], [phone]) were added in v2. They're
/// nullable so rows cached by older builds deserialize cleanly without
/// a schema migration.
@immutable
class SavedAddress {
  final String id;
  final AddressLabel label;
  final String recipientName;
  final String pincode;
  final String city;
  final String addressLine1;
  final String? addressLine2;
  final String? state;
  final String? phone;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  const SavedAddress({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.pincode,
    required this.city,
    required this.addressLine1,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.addressLine2,
    this.state,
    this.phone,
  });

  /// The short line we show on the home chip — e.g. "Jaipur 302017".
  String get shortLabel {
    final parts = <String>[];
    if (city.trim().isNotEmpty) parts.add(city.trim());
    if (pincode.trim().isNotEmpty) parts.add(pincode.trim());
    if (parts.isEmpty) return 'Saved location';
    return parts.join(' ');
  }

  /// The full multi-line label we show in the sheet row.
  String get composedAddress {
    final lines = <String>[
      addressLine1,
      if ((addressLine2 ?? '').trim().isNotEmpty) addressLine2!.trim(),
    ];
    return lines.join(', ');
  }

  /// One-liner shown under the city/pincode in the picker card —
  /// "12, MG Road · Near Metro · Ashok Vihar".
  String get detailLine {
    final parts = <String>[];
    if (addressLine1.trim().isNotEmpty) parts.add(addressLine1.trim());
    if ((addressLine2 ?? '').trim().isNotEmpty) parts.add(addressLine2!.trim());
    return parts.join(' · ');
  }

  SavedAddress copyWith({
    AddressLabel? label,
    String? recipientName,
    String? pincode,
    String? city,
    String? addressLine1,
    String? addressLine2,
    String? state,
    String? phone,
    double? latitude,
    double? longitude,
  }) =>
      SavedAddress(
        id: id,
        label: label ?? this.label,
        recipientName: recipientName ?? this.recipientName,
        pincode: pincode ?? this.pincode,
        city: city ?? this.city,
        addressLine1: addressLine1 ?? this.addressLine1,
        addressLine2: addressLine2 ?? this.addressLine2,
        state: state ?? this.state,
        phone: phone ?? this.phone,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label.storageValue,
        'recipientName': recipientName,
        'pincode': pincode,
        'city': city,
        'addressLine1': addressLine1,
        'addressLine2': addressLine2,
        'state': state,
        'phone': phone,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
        id: json['id'] as String,
        label: AddressLabelX.fromStorage(json['label'] as String?),
        recipientName: (json['recipientName'] as String?) ?? '',
        pincode: (json['pincode'] as String?) ?? '',
        city: (json['city'] as String?) ?? '',
        addressLine1: (json['addressLine1'] as String?) ?? '',
        addressLine2: json['addressLine2'] as String?,
        state: json['state'] as String?,
        phone: json['phone'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
      );

  // ───────────────────────────────────────────────────────────────
  // Supabase row ↔ model serialization.
  //
  // The on-wire shape uses snake_case (`recipient_name`, `is_selected`)
  // and server-side defaults for `user_id` + `created_at`. We keep the
  // older camelCase JSON helpers above for the SharedPreferences cache
  // path so a cold launch can paint instantly while the network fetch
  // resolves.
  // ───────────────────────────────────────────────────────────────

  /// Parse a `public.user_addresses` row (PostgREST response). Missing
  /// optional columns tolerate null so the factory survives schema
  /// drift during migrations.
  factory SavedAddress.fromRow(Map<String, dynamic> row) => SavedAddress(
        id: row['id'] as String,
        label: AddressLabelX.fromStorage(row['label'] as String?),
        recipientName: (row['recipient_name'] as String?) ?? '',
        pincode: (row['pincode'] as String?) ?? '',
        city: (row['city'] as String?) ?? '',
        addressLine1: (row['address_line1'] as String?) ?? '',
        addressLine2: row['address_line2'] as String?,
        state: row['state'] as String?,
        phone: row['phone'] as String?,
        latitude: (row['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (row['longitude'] as num?)?.toDouble() ?? 0,
        createdAt:
            DateTime.tryParse(row['created_at'] as String? ?? '') ??
                DateTime.now(),
      );

  /// Produce a PostgREST-ready payload for insert/upsert.
  ///
  /// * `user_id` is omitted — Supabase defaults it to `auth.uid()`.
  /// * `created_at` / `updated_at` are omitted — server-managed.
  /// * `is_selected` only included when [isSelected] is non-null; the
  ///   AddressService passes `true` when marking selection and leaves
  ///   it unset on pure edits so the trigger doesn't re-fire.
  /// * Zero lat/lng (our sentinel for "manually entered, no GPS") is
  ///   written as null so the column reflects actual knowledge.
  Map<String, dynamic> toRow({bool? isSelected}) {
    final hasCoords = latitude != 0 || longitude != 0;
    return {
      'id': id,
      'label': label.storageValue,
      'recipient_name': recipientName,
      'phone': phone,
      'pincode': pincode,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'state': state,
      'latitude': hasCoords ? latitude : null,
      'longitude': hasCoords ? longitude : null,
      if (isSelected != null) 'is_selected': isSelected,
    };
  }
}
