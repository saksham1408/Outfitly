import 'package:flutter/foundation.dart';

import '../domain/planner_event.dart';

/// In-memory store of the user's calendar-synced events.
///
/// Implemented as a singleton exposing a [ValueNotifier] so the calendar
/// screen (the top-half month grid), the event card, and the planner all
/// update in lockstep when an outfit is assigned — without dragging in
/// a state-management library for a single feature.
///
/// Real calendar sync (Google / Apple) is a future concern; we seed four
/// upcoming events so the grid always has highlighted days to discover.
class CalendarService {
  CalendarService._() {
    _seed();
  }
  static final CalendarService instance = CalendarService._();

  final ValueNotifier<List<PlannerEvent>> events = ValueNotifier(const []);

  void _seed() {
    final now = DateTime.now();
    DateTime d(int offsetDays) =>
        DateTime(now.year, now.month, now.day).add(Duration(days: offsetDays));

    events.value = [
      PlannerEvent(
        id: 'e1',
        title: "Arjun's Wedding",
        subtitle: 'Reception · Taj Lands End, Mumbai',
        date: d(3),
      ),
      PlannerEvent(
        id: 'e2',
        title: 'Quarterly Board Review',
        subtitle: 'Office · 10:00 AM',
        date: d(6),
      ),
      PlannerEvent(
        id: 'e3',
        title: 'Sunday Brunch with Riya',
        subtitle: 'Bandra · 11:30 AM',
        date: d(10),
      ),
      PlannerEvent(
        id: 'e4',
        title: 'Diwali Family Dinner',
        subtitle: 'Home · Dress ethnic',
        date: d(14),
      ),
    ];
  }

  /// Events falling on the given calendar date (ignoring time).
  List<PlannerEvent> forDay(DateTime day) {
    return events.value.where((e) => _sameDay(e.date, day)).toList();
  }

  /// Replace a single event's slot in the list, preserving order.
  void updateEvent(PlannerEvent updated) {
    final next = [...events.value];
    final idx = next.indexWhere((e) => e.id == updated.id);
    if (idx >= 0) {
      next[idx] = updated;
      events.value = next;
    }
  }

  /// Attach/replace the Mix-and-Match outfit on a specific event.
  void assignOutfit(String eventId, PlannedOutfit outfit) {
    final existing = events.value.firstWhere(
      (e) => e.id == eventId,
      orElse: () => throw StateError('Event $eventId not found'),
    );
    updateEvent(existing.copyWith(assignedOutfit: outfit));
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
