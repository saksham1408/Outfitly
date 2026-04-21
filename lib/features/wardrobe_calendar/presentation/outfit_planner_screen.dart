import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../data/calendar_service.dart';
import '../data/notification_service.dart';
import '../data/wardrobe_service.dart';
import '../domain/planner_event.dart';
import '../domain/wardrobe_item.dart';

/// The Mix-and-Match canvas.
///
/// Four vertical slots (Top → Bottom → Footwear → Accessory) are laid
/// out in visual order so the user can see the outfit taking shape. Each
/// empty slot invites a tap which opens a bottom sheet filtered to the
/// wardrobe items that fit that slot. Tapping a filled slot swaps or
/// clears it.
///
/// On save we write the [PlannedOutfit] back into [CalendarService] and
/// fire a notification confirmation so the planner feels "live".
class OutfitPlannerScreen extends StatefulWidget {
  final PlannerEvent event;

  const OutfitPlannerScreen({super.key, required this.event});

  @override
  State<OutfitPlannerScreen> createState() => _OutfitPlannerScreenState();
}

enum _Slot { top, bottom, footwear, accessory }

extension on _Slot {
  String get label {
    switch (this) {
      case _Slot.top:
        return 'Top';
      case _Slot.bottom:
        return 'Bottom';
      case _Slot.footwear:
        return 'Footwear';
      case _Slot.accessory:
        return 'Accessory';
    }
  }

  IconData get icon {
    switch (this) {
      case _Slot.top:
        return Icons.dry_cleaning_outlined;
      case _Slot.bottom:
        return Icons.straighten_rounded;
      case _Slot.footwear:
        return Icons.ice_skating_outlined;
      case _Slot.accessory:
        return Icons.diamond_outlined;
    }
  }

  /// Wardrobe types that can populate this slot. Ethnic wear is allowed
  /// into the Top slot so a full-length kurta can stand in for a shirt.
  List<WardrobeItemType> get allowedTypes {
    switch (this) {
      case _Slot.top:
        return [WardrobeItemType.top, WardrobeItemType.ethnic];
      case _Slot.bottom:
        return [WardrobeItemType.bottom];
      case _Slot.footwear:
        return [WardrobeItemType.shoes];
      case _Slot.accessory:
        return [WardrobeItemType.accessory];
    }
  }
}

class _OutfitPlannerScreenState extends State<OutfitPlannerScreen> {
  late PlannedOutfit _outfit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _outfit = widget.event.assignedOutfit ?? const PlannedOutfit();
  }

  WardrobeItem? _valueFor(_Slot slot) {
    switch (slot) {
      case _Slot.top:
        return _outfit.top;
      case _Slot.bottom:
        return _outfit.bottom;
      case _Slot.footwear:
        return _outfit.footwear;
      case _Slot.accessory:
        return _outfit.accessory;
    }
  }

  void _setValue(_Slot slot, WardrobeItem? item) {
    setState(() {
      switch (slot) {
        case _Slot.top:
          _outfit = _outfit.copyWith(top: item, clearTop: item == null);
          break;
        case _Slot.bottom:
          _outfit =
              _outfit.copyWith(bottom: item, clearBottom: item == null);
          break;
        case _Slot.footwear:
          _outfit =
              _outfit.copyWith(footwear: item, clearFootwear: item == null);
          break;
        case _Slot.accessory:
          _outfit = _outfit.copyWith(
              accessory: item, clearAccessory: item == null);
          break;
      }
    });
  }

  Future<void> _openPicker(_Slot slot) async {
    final options = WardrobeService.instance
        .all()
        .where((i) => slot.allowedTypes.contains(i.type))
        .toList();

    final selected = await showModalBottomSheet<_PickResult>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _PickerSheet(
        slot: slot,
        items: options,
        current: _valueFor(slot),
      ),
    );

    if (selected == null) return;
    if (selected.clear) {
      _setValue(slot, null);
    } else if (selected.item != null) {
      _setValue(slot, selected.item);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      CalendarService.instance.assignOutfit(widget.event.id, _outfit);
      // Refresh the event reference so the confirmation copy uses the
      // freshly assigned outfit.
      final updated = CalendarService.instance.events.value
          .firstWhere((e) => e.id == widget.event.id);
      await NotificationService.instance.confirmOutfitPlanned(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved · we\'ll remind you the night before.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_outfit.isEmpty && !_saving;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Mix & Match',
          style: GoogleFonts.newsreader(
            fontSize: 22,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Event banner ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.primary.withAlpha(10),
                border: Border.all(color: AppColors.primary.withAlpha(30)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Planning for ${widget.event.title}',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        if (widget.event.subtitle != null)
                          Text(
                            widget.event.subtitle!,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Canvas ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _SlotCanvas(
                    slot: _Slot.top,
                    item: _outfit.top,
                    onTap: () => _openPicker(_Slot.top),
                  ),
                  _SlotCanvas(
                    slot: _Slot.bottom,
                    item: _outfit.bottom,
                    onTap: () => _openPicker(_Slot.bottom),
                  ),
                  _SlotCanvas(
                    slot: _Slot.footwear,
                    item: _outfit.footwear,
                    onTap: () => _openPicker(_Slot.footwear),
                  ),
                  _SlotCanvas(
                    slot: _Slot.accessory,
                    item: _outfit.accessory,
                    onTap: () => _openPicker(_Slot.accessory),
                  ),
                ],
              ),
            ),

            // ── Save ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canSave ? _save : null,
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _outfit.isEmpty
                              ? 'PICK SOMETHING TO SAVE'
                              : 'SAVE TO CALENDAR',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.border.withAlpha(80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotCanvas extends StatelessWidget {
  final _Slot slot;
  final WardrobeItem? item;
  final VoidCallback onTap;

  const _SlotCanvas({
    required this.slot,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filled = item != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: filled ? AppColors.surface : AppColors.surfaceContainer,
            border: Border.all(
              color: filled
                  ? AppColors.primary.withAlpha(50)
                  : AppColors.border,
              width: filled ? 1.2 : 1.5,
              style: filled ? BorderStyle.solid : BorderStyle.solid,
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              if (filled)
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18),
                  ),
                  child: Image.network(
                    item!.imageUrl,
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 140,
                      color: AppColors.surfaceContainer,
                      child: const Icon(Icons.broken_image_outlined,
                          color: AppColors.textTertiary),
                    ),
                  ),
                )
              else
                Container(
                  width: 140,
                  height: 140,
                  alignment: Alignment.center,
                  child: Icon(
                    slot.icon,
                    size: 40,
                    color: AppColors.textTertiary.withAlpha(140),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        slot.label.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        filled ? item!.name : 'Add ${slot.label}',
                        style: GoogleFonts.newsreader(
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          color: filled
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            filled
                                ? Icons.swap_horiz_rounded
                                : Icons.add_circle_outline_rounded,
                            size: 14,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            filled ? 'Tap to swap' : 'Tap to pick',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Result from the picker sheet — either a new item, an explicit clear,
/// or null (sheet dismissed without a change).
class _PickResult {
  final WardrobeItem? item;
  final bool clear;
  const _PickResult({this.item, this.clear = false});
}

class _PickerSheet extends StatelessWidget {
  final _Slot slot;
  final List<WardrobeItem> items;
  final WardrobeItem? current;

  const _PickerSheet({
    required this.slot,
    required this.items,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.7;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(slot.icon, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pick a ${slot.label.toLowerCase()}',
                    style: GoogleFonts.newsreader(
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (current != null)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context)
                        .pop(const _PickResult(clear: true)),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: Text(
                      'Clear',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (items.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No ${slot.label.toLowerCase()} in your closet yet — add one from "My Closet".',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final it = items[i];
                  final isCurrent = it.id == current?.id;
                  return GestureDetector(
                    onTap: () => Navigator.of(context)
                        .pop(_PickResult(item: it)),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.primary
                              : AppColors.border.withAlpha(60),
                          width: isCurrent ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  it.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppColors.surfaceContainer,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                                if (isCurrent)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            color: AppColors.surface,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Text(
                              it.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
