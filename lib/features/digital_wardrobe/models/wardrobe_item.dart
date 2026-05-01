import 'package:flutter/foundation.dart';

/// Canonical category buckets for the Digital Wardrobe. Kept deliberately
/// small (four) so the Gemini stylist prompt stays short and ChoiceChip
/// pickers fit on one line. The string values match the `category` CHECK
/// constraint in migration `022_wardrobe_items.sql`.
const List<String> kWardrobeCategories = <String>[
  'Top',
  'Bottom',
  'Shoes',
  'Accessory',
];

/// The three "vibe" buckets the stylist understands. Kept as a flat enum
/// so `toRow()` / `fromRow()` can round-trip without a helper.
const List<String> kWardrobeStyles = <String>[
  'Casual',
  'Formal',
  'Party',
];

/// A convenient palette of color labels for the upload form's picker.
/// The column type is just `text` so users can hand-type exotic colors
/// later — these are only the defaults surfaced in the UI.
const List<String> kWardrobeColors = <String>[
  'Black',
  'White',
  'Beige',
  'Blue',
  'Navy',
  'Grey',
  'Brown',
  'Green',
  'Olive',
  'Red',
  'Pink',
  'Yellow',
  'Purple',
  'Multicolor',
];

/// One garment in the user's Personal Digital Wardrobe — the row that
/// the Daily AI Stylist reads to build an outfit from clothes the user
/// actually owns.
///
/// Mirrors `public.wardrobe_items` 1-for-1. [toRow] / [fromRow] handle
/// the snake_case ↔ camelCase translation; [toStylistJson] trims the
/// payload for the Gemini prompt so we don't waste tokens on timestamps
/// or URLs.
@immutable
class WardrobeItem {
  final String id;
  final String imageUrl;
  final String category;
  final String color;
  final String styleType;
  final DateTime createdAt;

  /// Whether accepted friends can see this item in their Friend Closet
  /// view. Defaults to true — onboarding feels social out of the box;
  /// users opt individual pieces *out*, not *in*. Mirrors the
  /// `wardrobe_items.is_shareable` column added in migration 031.
  final bool isShareable;

  /// The owner of this row. Always populated when [WardrobeItem] is
  /// fetched from a friend's closet (we need the id to send a borrow
  /// request) and when fetched from your own (it's just `auth.uid()`).
  /// Null only on locally-constructed transient instances that haven't
  /// hit Postgres yet.
  final String? userId;

  const WardrobeItem({
    required this.id,
    required this.imageUrl,
    required this.category,
    required this.color,
    required this.styleType,
    required this.createdAt,
    this.isShareable = true,
    this.userId,
  });

  /// Build from a PostgREST row (`public.wardrobe_items`).
  factory WardrobeItem.fromRow(Map<String, dynamic> row) => WardrobeItem(
        id: row['id'] as String,
        userId: row['user_id'] as String?,
        imageUrl: (row['image_url'] as String?) ?? '',
        category: (row['category'] as String?) ?? 'Top',
        color: (row['color'] as String?) ?? '',
        styleType: (row['style_type'] as String?) ?? 'Casual',
        // Default to true so legacy rows (pre-migration-031) behave as
        // the new code expects without a backfill — the migration also
        // backfills, so this is belt-and-braces.
        isShareable: (row['is_shareable'] as bool?) ?? true,
        createdAt:
            DateTime.tryParse(row['created_at'] as String? ?? '') ??
                DateTime.now(),
      );

  /// Insert payload for `public.wardrobe_items`. `user_id` and
  /// `created_at` are server-managed so we deliberately omit them.
  Map<String, dynamic> toRow() => {
        'id': id,
        'image_url': imageUrl,
        'category': category,
        'color': color,
        'style_type': styleType,
        'is_shareable': isShareable,
      };

  /// Minimal snapshot fed into the Gemini prompt. Drops noisy fields
  /// (URL, timestamp) that would cost tokens without helping the
  /// stylist reason about the outfit. The id is the only field we
  /// need back from the model to rehydrate the chosen items.
  Map<String, dynamic> toStylistJson() => {
        'id': id,
        'category': category,
        'color': color,
        'style': styleType,
      };

  /// Cheap copy with the shareable flag flipped — used by the toggle
  /// on each item card in the Personal Closet so the UI updates
  /// immediately while the Postgres UPDATE is in flight.
  WardrobeItem copyWith({bool? isShareable}) => WardrobeItem(
        id: id,
        userId: userId,
        imageUrl: imageUrl,
        category: category,
        color: color,
        styleType: styleType,
        createdAt: createdAt,
        isShareable: isShareable ?? this.isShareable,
      );
}
