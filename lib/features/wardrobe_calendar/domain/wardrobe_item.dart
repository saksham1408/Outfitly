/// High-level category a [WardrobeItem] falls into.
///
/// Drives both the filter tabs on the inventory screen and the slot
/// picker in the Mix-and-Match planner, so every garment gets routed
/// to the right place without string-matching.
enum WardrobeItemType {
  top,
  bottom,
  shoes,
  ethnic,
  accessory,
}

extension WardrobeItemTypeX on WardrobeItemType {
  String get label {
    switch (this) {
      case WardrobeItemType.top:
        return 'Top';
      case WardrobeItemType.bottom:
        return 'Bottom';
      case WardrobeItemType.shoes:
        return 'Shoes';
      case WardrobeItemType.ethnic:
        return 'Ethnic';
      case WardrobeItemType.accessory:
        return 'Accessory';
    }
  }
}

/// A single garment in the user's digital wardrobe.
///
/// `isFromOutfitly` distinguishes items the user actually purchased from
/// the app (so we can cross-link back to the product) from externally
/// added items the user photographed themselves. The [aspectRatio] is
/// stored up-front so the Pinterest-style masonry grid can lay out
/// without waiting for images to decode.
class WardrobeItem {
  final String id;
  final String name;
  final String imageUrl;
  final WardrobeItemType type;
  final bool isFromOutfitly;
  final double aspectRatio;

  const WardrobeItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.type,
    required this.isFromOutfitly,
    this.aspectRatio = 0.75,
  });
}
