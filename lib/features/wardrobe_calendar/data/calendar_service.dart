import 'package:flutter/foundation.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/planner_event.dart';

/// Supabase-backed store of the user's calendar events.
///
/// Singleton with a [ValueNotifier] so the calendar screen, the event
/// card, and the planner all rebuild in lockstep when data changes —
/// without dragging in a state-management library for a single feature.
///
/// Rows live in the `planner_events` table (see `018_planner_events.sql`),
/// one per user, filtered by RLS. The outfit is persisted as a small
/// id-only jsonb blob and rehydrated through [WardrobeService] so the
/// wardrobe catalogue stays the source of truth for item metadata.
class CalendarService {
  CalendarService._();
  static final CalendarService instance = CalendarService._();

  static const _table = 'planner_events';

  final ValueNotifier<List<PlannerEvent>> events = ValueNotifier(const []);
  bool _hasFetched = false;

  /// Pulls the full set of events for the signed-in user and pushes
  /// them into [events]. Safe to call multiple times; subsequent calls
  /// simply refresh the in-memory cache.
  Future<void> fetchAll() async {
    final userId = AppSupabase.client.auth.currentUser?.id;
    if (userId == null) {
      // No session means we have nothing to load; clear the cache so a
      // previous user's events don't leak across logins.
      events.value = const [];
      _hasFetched = true;
      return;
    }

    try {
      final rows = await AppSupabase.client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('event_date', ascending: true);

      events.value = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(PlannerEvent.fromRow)
          .toList();
      _hasFetched = true;
    } catch (e, st) {
      debugPrint('CalendarService.fetchAll failed: $e\n$st');
      // Preserve whatever cache we already have rather than wiping it
      // — a transient network blip shouldn't empty the month grid.
      rethrow;
    }
  }

  /// Ensures we've loaded at least once. Useful for screens that just
  /// want "whatever we've got" without forcing a refetch on every
  /// navigation.
  Future<void> ensureLoaded() async {
    if (_hasFetched) return;
    await fetchAll();
  }

  /// Creates a new event owned by the signed-in user. Returns the
  /// inserted [PlannerEvent] (with the server-generated id) so callers
  /// can immediately pass it to the planner or schedule a notification.
  Future<PlannerEvent> create({
    required String title,
    String? subtitle,
    required DateTime date,
  }) async {
    final userId = AppSupabase.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Cannot create an event without a signed-in user.');
    }

    // Persist the local wall-clock moment as UTC so every device reads
    // back the same instant; PlannerEvent.fromRow flips it back to local.
    final row = await AppSupabase.client
        .from(_table)
        .insert({
          'user_id': userId,
          'title': title,
          'subtitle': subtitle,
          'event_date': date.toUtc().toIso8601String(),
        })
        .select()
        .single();

    final created = PlannerEvent.fromRow(row);
    // Splice into the cached list in date order so the calendar reacts
    // without a full refetch.
    final next = [...events.value, created]
      ..sort((a, b) => a.date.compareTo(b.date));
    events.value = next;
    return created;
  }

  /// Events falling on the given calendar date (ignoring time).
  List<PlannerEvent> forDay(DateTime day) {
    return events.value.where((e) => _sameDay(e.date, day)).toList();
  }

  /// Persist a new/updated outfit for [eventId] and patch the cache.
  Future<PlannerEvent> assignOutfit(
    String eventId,
    PlannedOutfit outfit,
  ) async {
    final existing = events.value.firstWhere(
      (e) => e.id == eventId,
      orElse: () => throw StateError('Event $eventId not found'),
    );

    await AppSupabase.client
        .from(_table)
        .update({'outfit': outfit.toJson()})
        .eq('id', eventId);

    final updated = existing.copyWith(assignedOutfit: outfit);
    _replace(updated);
    return updated;
  }

  /// Deletes the event and removes it from the cache.
  Future<void> delete(String eventId) async {
    await AppSupabase.client.from(_table).delete().eq('id', eventId);
    events.value = events.value.where((e) => e.id != eventId).toList();
  }

  void _replace(PlannerEvent updated) {
    final next = [...events.value];
    final idx = next.indexWhere((e) => e.id == updated.id);
    if (idx >= 0) {
      next[idx] = updated;
      events.value = next;
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
