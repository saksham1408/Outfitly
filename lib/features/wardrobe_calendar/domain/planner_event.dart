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
}
