import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/planner_event.dart';

/// Thin wrapper around `flutter_local_notifications` scoped to the
/// Wardrobe Planner's day-of reminders.
///
/// On save we schedule a zoned notification for 8:00 AM on the event
/// day. If the event day is today and 8 AM has already passed, we fire
/// a reminder 10 seconds later instead — the user still gets immediate
/// confirmation the reminder pipeline is wired up.
///
/// We deliberately use [AndroidScheduleMode.inexactAllowWhileIdle] so
/// we don't require the `SCHEDULE_EXACT_ALARM` runtime permission on
/// Android 13+; an 8 AM outfit nudge doesn't need second-level precision.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  /// Hour the day-of reminder fires. Kept as a constant so the copy
  /// and the scheduling stay in lockstep.
  static const _reminderHour = 8;

  Future<void> init() async {
    if (_inited) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Ask for permissions up-front on iOS so the very first save
          // can actually deliver a notification; without this the OS
          // silently drops it until the user has opted in.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
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

  /// Schedules the day-of reminder for [event] at 8 AM local time. If
  /// 8 AM has already passed on the event day (or the event is in the
  /// past) we fall back to a "10 seconds from now" fire so the user
  /// still gets feedback that their outfit saved. Any prior reminder
  /// for the same event id is cancelled first so edits don't stack.
  Future<void> scheduleEventReminder(PlannerEvent event) async {
    await init();

    final notificationId = _idFor(event.id);
    try {
      await _plugin.cancel(notificationId);

      final now = tz.TZDateTime.now(tz.local);
      final eventDay = tz.TZDateTime(
        tz.local,
        event.date.year,
        event.date.month,
        event.date.day,
        _reminderHour,
      );
      final scheduled = eventDay.isAfter(now)
          ? eventDay
          : now.add(const Duration(seconds: 10));

      final outfit = event.assignedOutfit;
      final body = outfit == null || outfit.isEmpty
          ? "It's ${event.title} today — open Outfitly to plan your look."
          : "Today's pick for ${event.title} is ready. Have a great one!";

      await _plugin.zonedSchedule(
        notificationId,
        'Dressing up today ✨',
        body,
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'wardrobe_planner',
            'Outfit Planner',
            channelDescription:
                'Day-of reminders for events you\'ve planned outfits for.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          // presentBanner/List/Sound = true so iOS shows the banner
          // even when Outfitly is in the foreground. Without these
          // flags the OS suppresses the alert and the user assumes the
          // reminder never fired.
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, st) {
      debugPrint('NotificationService.scheduleEventReminder failed: $e\n$st');
    }
  }

  /// Fires an immediate "Reminder set" banner right after a save so the
  /// user gets visible proof the notification pipeline works, without
  /// having to wait for 8 AM on the event day. Uses a separate id from
  /// the scheduled day-of reminder so they don't clobber each other.
  Future<void> confirmReminderScheduled(PlannerEvent event) async {
    await init();
    try {
      final eventDay = _formatDay(event.date);
      await _plugin.show(
        _confirmIdFor(event.id),
        'Reminder set ✨',
        "We'll nudge you at 8:00 AM on $eventDay for ${event.title}.",
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'wardrobe_planner',
            'Outfit Planner',
            channelDescription:
                'Day-of reminders for events you\'ve planned outfits for.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('NotificationService.confirmReminderScheduled failed: $e');
    }
  }

  String _formatDay(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  /// Cancels a previously scheduled reminder (e.g. when the event is
  /// deleted). Safe to call even if nothing was scheduled.
  Future<void> cancelEventReminder(String eventId) async {
    await init();
    try {
      await _plugin.cancel(_idFor(eventId));
    } catch (e) {
      debugPrint('NotificationService.cancelEventReminder failed: $e');
    }
  }

  /// flutter_local_notifications needs a 32-bit int id. We derive it
  /// deterministically from the event's uuid so reschedules/cancels
  /// always target the same notification.
  int _idFor(String eventId) => eventId.hashCode & 0x7fffffff;

  /// Separate id namespace for the immediate "Reminder set" toast so
  /// it doesn't overwrite the scheduled day-of notification.
  int _confirmIdFor(String eventId) =>
      ('confirm_$eventId').hashCode & 0x7fffffff;

  /// Debug helper — schedules a notification to fire in [delay]
  /// seconds. Used by a long-press on the calendar FAB so developers
  /// can verify the zonedSchedule pipeline end-to-end without having
  /// to wait until 8 AM on an event day. Not wired up in release UI.
  Future<void> scheduleTestReminder({int delaySeconds = 10}) async {
    await init();
    try {
      final scheduled =
          tz.TZDateTime.now(tz.local).add(Duration(seconds: delaySeconds));
      await _plugin.zonedSchedule(
        999001,
        'Test reminder ⏱',
        'If you\'re reading this, scheduled notifications work.',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'wardrobe_planner',
            'Outfit Planner',
            channelDescription:
                'Day-of reminders for events you\'ve planned outfits for.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, st) {
      debugPrint('NotificationService.scheduleTestReminder failed: $e\n$st');
    }
  }
}
