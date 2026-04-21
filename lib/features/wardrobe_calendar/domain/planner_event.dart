import '../data/wardrobe_service.dart';
import 'wardrobe_item.dart';

/// The four slots the Mix-and-Match planner can fill. An event's
/// assigned outfit is always exactly one of these shapes so the canvas
/// can render deterministically.
class PlannedOutfit {
  final WardrobeItem? top;
  final WardrobeItem? bottom;
  final WardrobeItem? footwear;
  final WardrobeItem? accessory;

  const PlannedOutfit({
    this.top,
    this.bottom,
    this.footwear,
    this.accessory,
  });

  bool get isEmpty =>
      top == null && bottom == null && footwear == null && accessory == null;

  PlannedOutfit copyWith({
    WardrobeItem? top,
    WardrobeItem? bottom,
    WardrobeItem? footwear,
    WardrobeItem? accessory,
    bool clearTop = false,
    bool clearBottom = false,
    bool clearFootwear = false,
    bool clearAccessory = false,
  }) {
    return PlannedOutfit(
      top: clearTop ? null : (top ?? this.top),
      bottom: clearBottom ? null : (bottom ?? this.bottom),
      footwear: clearFootwear ? null : (footwear ?? this.footwear),
      accessory: clearAccessory ? null : (accessory ?? this.accessory),
    );
  }

  /// Serialises as just the wardrobe-item ids. Keeps the stored jsonb
  /// tight and lets the wardrobe catalogue be the source of truth for
  /// item metadata (name, image, type).
  Map<String, dynamic> toJson() => {
        'top_id': top?.id,
        'bottom_id': bottom?.id,
        'footwear_id': footwear?.id,
        'accessory_id': accessory?.id,
      };

  /// Rehydrates from the stored id-only shape by looking each id up in
  /// the local [WardrobeService]. Unknown ids resolve to null so a
  /// deleted item doesn't blow up the calendar.
  static PlannedOutfit? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    WardrobeItem? resolve(String key) {
      final id = json[key] as String?;
      return id == null ? null : WardrobeService.instance.byId(id);
    }

    final outfit = PlannedOutfit(
      top: resolve('top_id'),
      bottom: resolve('bottom_id'),
      footwear: resolve('footwear_id'),
      accessory: resolve('accessory_id'),
    );
    return outfit.isEmpty ? null : outfit;
  }
}

/// A calendar entry the user wants to dress for.
///
/// [assignedOutfit] is null until the user plans a look in the
/// Mix-and-Match screen; once set, the calendar surfaces the
/// accompanying image previews inline.
class PlannerEvent {
  final String id;
  final String title;
  final String? subtitle;
  final DateTime date;
  final PlannedOutfit? assignedOutfit;

  const PlannerEvent({
    required this.id,
    required this.title,
    required this.date,
    this.subtitle,
    this.assignedOutfit,
  });

  PlannerEvent copyWith({
    String? title,
    String? subtitle,
    DateTime? date,
    PlannedOutfit? assignedOutfit,
    bool clearOutfit = false,
  }) {
    return PlannerEvent(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      date: date ?? this.date,
      assignedOutfit:
          clearOutfit ? null : (assignedOutfit ?? this.assignedOutfit),
    );
  }

  /// Parses a row from the `planner_events` Supabase table.
  factory PlannerEvent.fromRow(Map<String, dynamic> row) {
    return PlannerEvent(
      id: row['id'] as String,
      title: row['title'] as String,
      subtitle: row['subtitle'] as String?,
      // Supabase returns a UTC-flagged ISO string; flip to local so the
      // month grid & time pickers read naturally.
      date: DateTime.parse(row['event_date'] as String).toLocal(),
      assignedOutfit: PlannedOutfit.fromJson(
        row['outfit'] as Map<String, dynamic>?,
      ),
    );
  }
}
