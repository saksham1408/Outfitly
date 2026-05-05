import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../router/app_router.dart';
import 'device_token_service.dart';

/// FCM-backed push notification service.
///
/// Three lifecycles share one service:
///
///   * **Cold start** — app was terminated, the user tapped the
///     notification banner from the system tray. We read
///     `FirebaseMessaging.instance.getInitialMessage()` once on
///     boot and route based on its `data` payload.
///   * **Background tap** — app was suspended, user tapped the
///     banner. `onMessageOpenedApp` fires; we route the same way.
///   * **Foreground** — app is open. iOS/Android by default DON'T
///     show a banner for foreground messages, so we hand the
///     payload to `flutter_local_notifications` to display one,
///     then route on tap of the local notification.
///
/// The deep-link contract:
///   * The server sets `data.route` on the FCM message. e.g.
///     `data: { route: '/offers' }` for a sale-launch push.
///   * The client routes via [AppRouter.router] (a static GoRouter
///     instance) so navigation works from the background isolate
///     without a `BuildContext`.
///
/// Defensive boot:
///   * If Firebase isn't configured (no google-services.json /
///     GoogleService-Info.plist), [initialize] catches and logs.
///     The rest of the app continues to boot — only push
///     delivery is dark until configs are added.
///   * Permission denial is also a soft failure; the app stays
///     usable, the user just won't see notifications.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance =
      PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'outfitly_default',
    'Outfitly Notifications',
    description:
        'Sale launches, borrow requests, tailor visit updates.',
    importance: Importance.high,
  );

  bool _initialized = false;

  /// One-time boot. Call AFTER `Firebase.initializeApp()` lands —
  /// usually from `main()` once the supabase + dotenv steps are
  /// done. Safe to call multiple times; the second invocation
  /// no-ops.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Permissions. iOS-mandatory (returns AuthorizationStatus
      // .denied / .notDetermined / .authorized / .provisional).
      // Android 13+ also requires runtime permission, which the
      // FCM plugin handles transparently when we call this.
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[push] permission status: ${settings.authorizationStatus}');

      // Foreground iOS presentation — without this, iOS hides
      // the banner when the app is open. Even with this on,
      // we still mirror to flutter_local_notifications so
      // Android matches.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Local notifications channel (Android requires explicit
      // channel registration on API 26+; iOS is no-op).
      const androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _localNotifications.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: _onLocalTap,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);

      // Foreground messages — show via local notification then
      // wait for the user to tap.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Background tap: app was suspended, user tapped banner.
      FirebaseMessaging.onMessageOpenedApp.listen(
        (msg) => _handleRoute(msg.data),
      );

      // Cold start: app was terminated, user tapped banner.
      // FirebaseMessaging delivers the message that woke the
      // process; we route as soon as the GoRouter's first
      // frame is mounted (best-effort 800ms post-init delay
      // gives the splash → home transition time to land).
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        Future.delayed(
          const Duration(milliseconds: 800),
          () => _handleRoute(initialMessage.data),
        );
      }

      // Token rotates on reinstall + sometimes silently mid-
      // session; refresh the row in `device_tokens` whenever
      // FCM hands us a new value.
      FirebaseMessaging.instance.onTokenRefresh.listen((_) {
        DeviceTokenService().registerCurrent();
      });

      debugPrint('[push] initialized');
    } catch (e, st) {
      // Most likely cause: Firebase wasn't initialized (missing
      // config files). We log and move on — the app keeps
      // running, only push delivery is dark.
      debugPrint('[push] init failed (no Firebase config?): $e\n$st');
    }
  }

  // ── Foreground handler ───────────────────────────────────

  /// Render an FCM payload as a local notification while the app
  /// is in the foreground. We pack the FCM `data` map into the
  /// local notification's `payload` field so the on-tap handler
  /// can route off it the same way `onMessageOpenedApp` does.
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;

    await _localNotifications.show(
      message.messageId.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Local-notification tap handler — fires when the user taps a
  /// banner the app itself rendered (i.e. while in foreground).
  /// We deserialise the original FCM data map and run it through
  /// [_handleRoute] so the routing logic lives in one place.
  void _onLocalTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _handleRoute(data);
    } catch (e) {
      debugPrint('[push] failed to decode local payload: $e');
    }
  }

  // ── Routing ───────────────────────────────────────────────

  /// The single deep-link decision point. Reads `data['route']`
  /// and pushes via the static GoRouter — no BuildContext
  /// required, so this works from background-isolate handlers
  /// and cold-start callbacks alike.
  ///
  /// Unknown routes are logged and ignored rather than crashed —
  /// a server-side typo shouldn't take the app down.
  void _handleRoute(Map<String, dynamic> data) {
    final route = data['route'] as String?;
    if (route == null || route.isEmpty) {
      debugPrint('[push] tap with no route data — staying put');
      return;
    }
    try {
      AppRouter.router.push(route);
      debugPrint('[push] routed to $route');
    } catch (e) {
      debugPrint('[push] route push failed for $route: $e');
    }
  }
}
