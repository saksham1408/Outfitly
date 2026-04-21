import 'package:flutter/foundation.dart';

/// Discriminator for the small "HOME / WORK / OTHER" badge we show next
/// to each saved address. Kept as an enum so the UI can't render a
/// typo'd label.
enum AddressLabel { home, work, other }

extension AddressLabelX on AddressLabel {
  String get displayLabel => switch (this) {
        AddressLabel.home => 'HOME',
        AddressLabel.work => 'WORK',
        AddressLabel.other => 'OTHER',
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
@immutable
class SavedAddress {
  final String id;
  final AddressLabel label;
  final String recipientName;
  final String pincode;
  final String city;
  final String addressLine1;
  final String? addressLine2;
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

  SavedAddress copyWith({
    AddressLabel? label,
    String? recipientName,
    String? pincode,
    String? city,
    String? addressLine1,
    String? addressLine2,
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
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
      );
}
