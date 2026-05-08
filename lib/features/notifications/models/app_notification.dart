import 'package:flutter/foundation.dart';

/// Source/category of a notification — drives the icon + accent
/// colour rendered on each row of the in-app feed.
///
/// Maps to the `type` column on `public.notifications`. We keep
/// the column free-text so a future engineer adding a new push
/// type doesn't need a migration; this enum picks specific
/// visual treatments for the categories we know about and falls
/// back to [system] for anything unrecognised.
enum NotificationKind {
  promo,
  borrow,
  appointment,
  pickup,
  system;

  static NotificationKind fromDb(String? raw) {
    switch (raw) {
      case 'promo':
        return NotificationKind.promo;
      case 'borrow':
        return NotificationKind.borrow;
      case 'appointment':
        return NotificationKind.appointment;
      case 'pickup':
        return NotificationKind.pickup;
      case 'system':
      default:
        return NotificationKind.system;
    }
  }

  String get dbValue {
    switch (this) {
      case NotificationKind.promo:
        return 'promo';
      case NotificationKind.borrow:
        return 'borrow';
      case NotificationKind.appointment:
        return 'appointment';
      case NotificationKind.pickup:
        return 'pickup';
      case NotificationKind.system:
        return 'system';
    }
  }
}

/// One row from `public.notifications`.
///
/// Read-only on the customer client — rows are written by the
/// notify-* edge functions running with the service role
/// (long-term) or via direct INSERT in the SQL editor (today).
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.kind,
    required this.createdAt,
    this.body,
    this.route,
    this.data,
    this.readAt,
  });

  final String id;
  final String userId;
  final String title;
  final String? body;
  final NotificationKind kind;
  final String? route;
  final Map<String, dynamic>? data;
  final DateTime? readAt;
  final DateTime createdAt;

  /// True until the user opens the row (or hits "mark all read").
  /// The bell-icon badge counts unread rows.
  bool get isUnread => readAt == null;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: (map['title'] as String?)?.trim() ?? 'Notification',
      body: (map['body'] as String?)?.trim().isEmpty ?? true
          ? null
          : (map['body'] as String).trim(),
      kind: NotificationKind.fromDb(map['type'] as String?),
      route: (map['route'] as String?)?.trim().isEmpty ?? true
          ? null
          : (map['route'] as String).trim(),
      data: map['data'] is Map<String, dynamic>
          ? map['data'] as Map<String, dynamic>
          : null,
      readAt: DateTime.tryParse(map['read_at'] as String? ?? '')?.toLocal(),
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}
