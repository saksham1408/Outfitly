import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../models/app_notification.dart';

/// Customer-side data layer for the in-app notifications feed.
///
/// Three surfaces:
///   * [watch]            — Realtime stream of every row
///                          belonging to the calling user, newest
///                          first. Drives the feed list.
///   * [unreadCountStream]— Realtime int stream that the home
///                          AppBar's bell-icon badge subscribes to.
///   * [markAsRead] /
///     [markAllAsRead]    — flip `read_at` on a single row or the
///                          whole inbox.
///
/// Singleton because the bell-icon badge and the feed both bind
/// to the same streams; sharing one repository keeps a single
/// websocket subscription instead of one per consumer.
class NotificationsRepository {
  NotificationsRepository._({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  static final NotificationsRepository instance = NotificationsRepository._();

  final SupabaseClient _client;

  static const String _table = 'notifications';

  // ── Reads ────────────────────────────────────────────────

  /// Realtime feed of the user's notifications, newest first.
  /// RLS scopes the row set to `auth.uid() = user_id` — the
  /// client doesn't need to filter explicitly.
  Stream<List<AppNotification>> watch() {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .map(AppNotification.fromMap)
              .toList(growable: false),
        );
  }

  /// Live unread count — drives the bell-icon badge. Derived
  /// from [watch] so we don't pay for a second websocket
  /// subscription. Re-emits whenever any row mutates.
  Stream<int> unreadCountStream() {
    return watch().map(
      (list) => list.where((n) => n.isUnread).length,
    );
  }

  /// One-shot fetch — used as a fallback when the screen wants
  /// the current snapshot before the stream's first emission
  /// lands.
  Future<List<AppNotification>> fetchRecent({int limit = 50}) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(AppNotification.fromMap)
          .toList(growable: false);
    } catch (e, st) {
      debugPrint('NotificationsRepository.fetchRecent failed — $e\n$st');
      return const [];
    }
  }

  // ── Mutations ────────────────────────────────────────────

  /// Mark a single notification read. RLS gates this to
  /// `auth.uid() = user_id` so a user can never flip another
  /// user's row.
  Future<void> markAsRead(String id) async {
    try {
      await _client
          .from(_table)
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
    } catch (e, st) {
      debugPrint('NotificationsRepository.markAsRead failed — $e\n$st');
    }
  }

  /// Bulk-flip every unread row for the calling user. The bell
  /// icon's "Mark all as read" CTA lands here. We let RLS scope
  /// the set instead of a `WHERE user_id = me` predicate so the
  /// query can't accidentally walk past it.
  Future<void> markAllAsRead() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client
          .from(_table)
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', user.id)
          .filter('read_at', 'is', null);
    } catch (e, st) {
      debugPrint('NotificationsRepository.markAllAsRead failed — $e\n$st');
    }
  }

  /// Swipe-to-dismiss support. Hard delete because the user
  /// explicitly threw it away — soft-delete would leave the row
  /// visible on a re-installed device.
  Future<void> delete(String id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } catch (e, st) {
      debugPrint('NotificationsRepository.delete failed — $e\n$st');
    }
  }
}
