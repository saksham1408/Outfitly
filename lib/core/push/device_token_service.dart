import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/supabase_client.dart';

/// Persists the current device's push-notification token in
/// `public.device_tokens` so the server can fan out pushes to every
/// device the signed-in user has the customer app installed on.
///
/// This service intentionally does NOT depend on `firebase_messaging`
/// yet — the FCM / APNs integration is a follow-up that adds the
/// native platform plumbing. When that lands, the only change here is
/// to replace [_fetchPlatformToken] with a call into
/// `FirebaseMessaging.instance.getToken()` (plus the APNs permission
/// prompt on iOS). Every other seam — register / unregister / the
/// Supabase UPSERT — is already in place.
///
/// Usage:
///
/// ```dart
/// // After the user signs in (e.g. from an auth state listener):
/// await DeviceTokenService().registerCurrent();
///
/// // Before the user signs out:
/// await DeviceTokenService().unregisterCurrent();
/// ```
///
/// Unimplemented platform gracefully no-ops — registering from the
/// web build or a platform we haven't scaffolded yet is a logged
/// warning, not a thrown error, so the auth flow never fails because
/// of a missing push token.
class DeviceTokenService {
  DeviceTokenService({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  final SupabaseClient _client;

  static const String _table = 'device_tokens';

  /// Which app this service runs inside. The same Supabase project
  /// backs both the customer and the Outfitly Tailor Partner apps;
  /// the `app` column lets the server decide which notification
  /// topic a given token belongs to.
  static const String _appTag = 'customer';

  /// Fetch the current push token and UPSERT it into `device_tokens`.
  /// Safe to call multiple times — the UNIQUE constraint on `token`
  /// means we either insert a fresh row or bump `updated_at` on the
  /// existing one.
  Future<void> registerCurrent() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('[push] skipping token register — not signed in');
      return;
    }

    final platform = _currentPlatform();
    if (platform == null) {
      debugPrint('[push] unsupported platform — skipping register');
      return;
    }

    final token = await _fetchPlatformToken(platform);
    if (token == null) {
      debugPrint('[push] no token available — scaffold stub');
      return;
    }

    try {
      // UPSERT on the unique token column. On reinstall the token
      // rotates and we get a fresh row; on a re-open we bump
      // updated_at so the purge job can prune stale devices.
      await _client.from(_table).upsert(
        {
          'user_id': user.id,
          'token': token,
          'platform': platform,
          'app': _appTag,
        },
        onConflict: 'token',
      );
      debugPrint('[push] device token registered ($platform, $_appTag)');
    } catch (e) {
      // Never let a push-token failure crash auth. Log and move on.
      debugPrint('[push] register failed: $e');
    }
  }

  /// Delete the current device's token. Called on explicit sign-out
  /// so a previously-signed-in user doesn't keep getting pushes for
  /// the new user's account on this device.
  Future<void> unregisterCurrent() async {
    final platform = _currentPlatform();
    if (platform == null) return;

    final token = await _fetchPlatformToken(platform);
    if (token == null) return;

    try {
      await _client.from(_table).delete().eq('token', token);
      debugPrint('[push] device token unregistered');
    } catch (e) {
      debugPrint('[push] unregister failed: $e');
    }
  }

  /// Normalise `Platform.operatingSystem` to the values our CHECK
  /// constraint accepts. Returns null for web / desktop targets
  /// we're not shipping push to yet.
  String? _currentPlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
    } catch (_) {
      // Platform.isX throws on unsupported targets. Fall through.
    }
    return null;
  }

  /// Scaffold stub — replaced by the real FCM / APNs fetch once
  /// the native platform config lands (GoogleService-Info.plist /
  /// google-services.json + firebase_messaging dependency). Returns
  /// null today so callers no-op cleanly.
  Future<String?> _fetchPlatformToken(String platform) async {
    // TODO(push): replace with:
    //   await FirebaseMessaging.instance.requestPermission();
    //   return FirebaseMessaging.instance.getToken();
    return null;
  }
}
