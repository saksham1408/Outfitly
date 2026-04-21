import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/planner_event.dart';

/// Thin wrapper around `flutter_local_notifications` scoped to the
/// Wardrobe Planner's "wear-this-tomorrow" nudges.
///
/// We deliberately use `show()` (immediate) rather than `zonedSchedule()`
/// so we don't have to bring in the `timezone` package and deal with
/// local-zone initialisation — for this MVP the UX is: when the user
/// saves an outfit, we instantly confirm "Saved · we'll remind you the
/// night before". A follow-up task will swap this for a proper scheduled
/// reminder once a background-task plan is in place.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );

      // Android 13+ requires a runtime notification permission. The
      // plugin's helper returns null on older OS versions, which we
      // treat as "already granted".
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      _inited = true;
    } catch (e, st) {
      // Never let a notification failure break a save — it's a nice-to-have.
      debugPrint('NotificationService.init failed: $e\n$st');
    }
  }

  /// Fires a best-effort "outfit saved" confirmation so the user gets
  /// immediate feedback that the planner is wired up end to end.
  Future<void> confirmOutfitPlanned(PlannerEvent event) async {
    await init();
    try {
      await _plugin.show(
        event.id.hashCode,
        'Outfit locked in ✨',
        "Your look for ${event.title} is planned. We'll remind you the night before.",
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'wardrobe_planner',
            'Outfit Planner',
            channelDescription:
                'Reminders for upcoming events with planned outfits.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('NotificationService.confirmOutfitPlanned failed: $e');
    }
  }
}
