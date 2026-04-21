import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The status of the most recent location request. The UI keys off this
/// to flip between "Getting location…", the resolved address, or an
/// "Enable location" CTA.
enum LocationStatus {
  /// Haven't asked yet (fresh install, no cache).
  idle,

  /// In flight — permission prompt is up, or we're fetching coordinates,
  /// or reverse-geocoding.
  loading,

  /// Resolved — [DeliveryLocation.city] + [DeliveryLocation.postalCode]
  /// are populated.
  resolved,

  /// User denied the OS prompt (or it was permanently denied). We keep
  /// whatever cached value we had but mark the status so the UI can show
  /// a tap-to-retry affordance.
  denied,

  /// Location services are turned off at the OS level (airplane mode,
  /// sim with no location set, etc.).
  servicesDisabled,

  /// Everything else — network failure during reverse geocode, plugin
  /// error, timeout.
  error,
}

/// A resolved delivery address as we display it on the home header.
/// Kept deliberately small — city + pincode is what drives the chip;
/// anything finer-grained (exact street) belongs on the checkout form.
@immutable
class DeliveryLocation {
  final String city;
  final String? region;
  final String? postalCode;
  final double latitude;
  final double longitude;
  final DateTime resolvedAt;

  const DeliveryLocation({
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.resolvedAt,
    this.region,
    this.postalCode,
  });

  /// The short label we render inline: "Mumbai 400001" or, if we don't
  /// have a pincode, just "Mumbai". Falls back to "Current location"
  /// when the city is empty (can happen in remote areas).
  String get displayLabel {
    final parts = <String>[];
    if (city.trim().isNotEmpty) parts.add(city.trim());
    if ((postalCode ?? '').trim().isNotEmpty) parts.add(postalCode!.trim());
    if (parts.isEmpty) return 'Current location';
    return parts.join(' ');
  }

  Map<String, dynamic> toJson() => {
        'city': city,
        'region': region,
        'postalCode': postalCode,
        'latitude': latitude,
        'longitude': longitude,
        'resolvedAt': resolvedAt.toIso8601String(),
      };

  factory DeliveryLocation.fromJson(Map<String, dynamic> json) =>
      DeliveryLocation(
        city: (json['city'] as String?) ?? '',
        region: json['region'] as String?,
        postalCode: json['postalCode'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        resolvedAt: DateTime.tryParse(json['resolvedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Singleton that owns the user's "deliver to" location end-to-end:
/// permission prompt, position fetch, reverse geocoding, and a persisted
/// cache so cold launches don't flicker.
///
/// UI reads [location] and [status] — both [ValueListenable]s — so
/// widgets can rebuild via `ValueListenableBuilder` without the service
/// caring about widget trees.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const _cacheKey = 'vastrahub.delivery_location.v1';

  /// Reported once a day feels about right — country hops should refresh,
  /// but walking around Mumbai shouldn't keep re-prompting. Beyond this
  /// age [ensure] silently re-fetches.
  static const _staleAfter = Duration(hours: 24);

  final ValueNotifier<DeliveryLocation?> _location =
      ValueNotifier<DeliveryLocation?>(null);
  final ValueNotifier<LocationStatus> _status =
      ValueNotifier<LocationStatus>(LocationStatus.idle);

  ValueListenable<DeliveryLocation?> get location => _location;
  ValueListenable<LocationStatus> get status => _status;

  /// Internal flag so we don't fire two concurrent fetches when a user
  /// taps the chip while the initial resolution is already in flight.
  bool _inFlight = false;

  /// Hydrate the cached location (if any) and kick off a refresh when
  /// the cache is empty or stale. Safe to call repeatedly — calls beyond
  /// the first one are no-ops as long as one is already running.
  Future<void> ensure() async {
    if (_location.value == null) {
      await _loadCache();
    }
    final cached = _location.value;
    final fresh = cached != null &&
        DateTime.now().difference(cached.resolvedAt) < _staleAfter;
    if (fresh) {
      _status.value = LocationStatus.resolved;
      return;
    }
    await refresh();
  }

  /// Forces a new permission prompt + position fetch. Called when the
  /// user taps the location chip on the home header.
  Future<void> refresh() async {
    if (_inFlight) return;
    _inFlight = true;
    _status.value = LocationStatus.loading;
    try {
      // 1. Services on?
      final servicesOn = await Geolocator.isLocationServiceEnabled();
      if (!servicesOn) {
        _status.value = LocationStatus.servicesDisabled;
        return;
      }

      // 2. Permission.
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _status.value = LocationStatus.denied;
        return;
      }

      // 3. Position — give up after 10s rather than hang the header.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // 4. Reverse geocode. Falls back gracefully if the lookup fails —
      // the coords are still useful on their own.
      String city = '';
      String? region;
      String? postal;
      try {
        final placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          city = _firstNonEmpty([
            p.locality,
            p.subAdministrativeArea,
            p.administrativeArea,
          ]);
          region = _firstNullable([p.administrativeArea, p.country]);
          postal = _firstNullable([p.postalCode]);
        }
      } catch (e) {
        debugPrint('LocationService: reverse geocode failed — $e');
      }

      final resolved = DeliveryLocation(
        city: city,
        region: region,
        postalCode: postal,
        latitude: pos.latitude,
        longitude: pos.longitude,
        resolvedAt: DateTime.now(),
      );
      _location.value = resolved;
      _status.value = LocationStatus.resolved;
      await _writeCache(resolved);
    } on TimeoutException {
      _status.value = LocationStatus.error;
    } catch (e, st) {
      debugPrint('LocationService.refresh failed — $e\n$st');
      _status.value = LocationStatus.error;
    } finally {
      _inFlight = false;
    }
  }

  /// Awaits a fresh resolution end-to-end and returns the resulting
  /// [DeliveryLocation]. Unlike [refresh] this throws on failure so the
  /// caller (e.g. the "Use my current location" button in the address
  /// sheet) can surface a precise error in the UI.
  Future<DeliveryLocation> resolveOnce() async {
    await refresh();
    final loc = _location.value;
    if (loc != null && _status.value == LocationStatus.resolved) return loc;
    switch (_status.value) {
      case LocationStatus.denied:
        throw StateError(
            'Location access is denied. Enable it in Settings to detect your delivery address.');
      case LocationStatus.servicesDisabled:
        throw StateError(
            'Location services are off on this device. Turn them on to detect your delivery address.');
      default:
        throw StateError(
            'Could not detect your location right now. Please try again or enter a pincode manually.');
    }
  }

  /// Deep-links into the OS settings. Used when the OS permission is
  /// [LocationPermission.deniedForever] — we can't re-prompt from inside
  /// the app, only nudge the user to flip the toggle manually.
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Deep-links into the system Location Services toggle (the global
  /// one). Used when services are off at the OS level.
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  // ───────────────────────── private ─────────────────────────

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      _location.value = DeliveryLocation.fromJson(decoded);
      _status.value = LocationStatus.resolved;
    } catch (e) {
      debugPrint('LocationService: cache read failed — $e');
    }
  }

  Future<void> _writeCache(DeliveryLocation loc) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(loc.toJson()));
    } catch (e) {
      debugPrint('LocationService: cache write failed — $e');
    }
  }

  String _firstNonEmpty(List<String?> options) {
    for (final o in options) {
      if (o != null && o.trim().isNotEmpty) return o.trim();
    }
    return '';
  }

  String? _firstNullable(List<String?> options) {
    for (final o in options) {
      if (o != null && o.trim().isNotEmpty) return o.trim();
    }
    return null;
  }
}
