import 'package:flutter/foundation.dart';

import 'family_member.dart';

/// One garment in a coordinated combo set — the per-member
/// breakdown on the Lookbook card shows a list of these.
@immutable
class ComboItem {
  const ComboItem({
    required this.role,
    required this.productName,
    required this.price,
    this.imageUrl,
  });

  /// Which family member this item is for. Roster-aware UIs
  /// render a "Father:", "Mother:", "Son:" label by reading
  /// `role.label`.
  final FamilyRole role;

  final String productName;

  /// INR-denominated. The Money service handles locale-aware
  /// rendering at the call site; this stays in the catalog's
  /// base currency so the combo discount math is exact.
  final double price;

  /// Optional per-item product photo. The Lookbook lead-image is
  /// the master collage on the [ComboSet]; per-item photos let
  /// the breakdown row render thumbnails.
  final String? imageUrl;
}

/// One coordinated outfit set — e.g. "Royal Blue Diwali Set".
/// Bundles a list of role-keyed items, an automatic combo
/// discount, and the visual identity (name, tagline, master
/// image, palette colour) the Lookbook card needs to look
/// premium without per-product photography.
@immutable
class ComboSet {
  const ComboSet({
    required this.id,
    required this.name,
    required this.tagline,
    required this.items,
    required this.paletteColor,
    this.heroImageUrl,
    this.discountPercent = 10.0,
  });

  /// Stable id — a hash of the template + roster so list state
  /// (favourites, "added to cart" markers) stays stable across
  /// rebuilds.
  final String id;

  /// Marketing-facing name. Drives the Lookbook hero text.
  final String name;

  /// Sub-line under the name on the card. One sentence; merch
  /// hand-curates these (or we generate from a template).
  final String tagline;

  /// Each entry is one garment for one family member. Rosters
  /// with multiple kids of the same gender produce duplicate
  /// items here (one per child).
  final List<ComboItem> items;

  /// 0xAARRGGBB hex — drives the gradient + accent colour on the
  /// Lookbook card so each set has its own visual identity. We
  /// use the int form rather than `Color` to keep this model
  /// dependency-free of Flutter's `dart:ui`.
  final int paletteColor;

  final String? heroImageUrl;

  /// Automatic combo discount applied to the bundled set —
  /// rewards the customer for buying the whole look together.
  /// Default 10% per the spec; merch can tune per-set later.
  final double discountPercent;

  /// Sum of every item's INR price before the combo discount.
  double get totalPrice =>
      items.fold(0.0, (sum, item) => sum + item.price);

  /// Final price after the [discountPercent] is applied.
  double get discountedPrice =>
      totalPrice * (1 - discountPercent / 100.0);

  /// INR saved by buying the set vs. assembling it piece by piece.
  /// Powers the "You save ₹X" beat under the price strip.
  double get savings => totalPrice - discountedPrice;
}
