import '../domain/wardrobe_item.dart';

/// Read-only source of the user's digital closet.
///
/// For the MVP we seed a realistic 12-item wardrobe (8 from Outfitly,
/// 4 external) so the grid, tabs, and planner slots all have content
/// to exercise without a backend. Images are pulled from Unsplash so
/// they load on any device. Each item ships with an [aspectRatio] so
/// the masonry grid can lay out without image-decode jank.
class WardrobeService {
  WardrobeService._();
  static final WardrobeService instance = WardrobeService._();

  static const _items = <WardrobeItem>[
    // ── Tops ──
    WardrobeItem(
      id: 'w1',
      name: 'Crisp White Oxford',
      imageUrl:
          'https://images.unsplash.com/photo-1598033129183-c4f50c736f10?w=800&q=80',
      type: WardrobeItemType.top,
      isFromOutfitly: true,
      aspectRatio: 0.75,
    ),
    WardrobeItem(
      id: 'w2',
      name: 'Navy Cotton Henley',
      imageUrl:
          'https://images.unsplash.com/photo-1618354691373-d851c5c3a990?w=800&q=80',
      type: WardrobeItemType.top,
      isFromOutfitly: true,
      aspectRatio: 0.82,
    ),
    WardrobeItem(
      id: 'w3',
      name: 'Charcoal Linen Shirt',
      imageUrl:
          'https://images.unsplash.com/photo-1602810318383-e386cc2a3ccf?w=800&q=80',
      type: WardrobeItemType.top,
      isFromOutfitly: false,
      aspectRatio: 0.68,
    ),
    WardrobeItem(
      id: 'w4',
      name: 'Olive Polo Tee',
      imageUrl:
          'https://images.unsplash.com/photo-1586790170083-2f9ceadc732d?w=800&q=80',
      type: WardrobeItemType.top,
      isFromOutfitly: true,
      aspectRatio: 0.88,
    ),

    // ── Bottoms ──
    WardrobeItem(
      id: 'w5',
      name: 'Indigo Selvedge Jeans',
      imageUrl:
          'https://images.unsplash.com/photo-1542272604-787c3835535d?w=800&q=80',
      type: WardrobeItemType.bottom,
      isFromOutfitly: true,
      aspectRatio: 0.70,
    ),
    WardrobeItem(
      id: 'w6',
      name: 'Stone Chino Trousers',
      imageUrl:
          'https://images.unsplash.com/photo-1473966968600-fa801b869a1a?w=800&q=80',
      type: WardrobeItemType.bottom,
      isFromOutfitly: false,
      aspectRatio: 0.78,
    ),
    WardrobeItem(
      id: 'w7',
      name: 'Black Tailored Trousers',
      imageUrl:
          'https://images.unsplash.com/photo-1624378439575-d8705ad7ae80?w=800&q=80',
      type: WardrobeItemType.bottom,
      isFromOutfitly: true,
      aspectRatio: 0.72,
    ),

    // ── Shoes ──
    WardrobeItem(
      id: 'w8',
      name: 'White Leather Sneakers',
      imageUrl:
          'https://images.unsplash.com/photo-1549298916-b41d501d3772?w=800&q=80',
      type: WardrobeItemType.shoes,
      isFromOutfitly: false,
      aspectRatio: 1.0,
    ),
    WardrobeItem(
      id: 'w9',
      name: 'Tan Derby Shoes',
      imageUrl:
          'https://images.unsplash.com/photo-1533867617858-e7b97e060509?w=800&q=80',
      type: WardrobeItemType.shoes,
      isFromOutfitly: true,
      aspectRatio: 1.1,
    ),

    // ── Ethnic ──
    WardrobeItem(
      id: 'w10',
      name: 'Ivory Silk Kurta',
      imageUrl:
          'https://images.unsplash.com/photo-1610088441520-4352457e7095?w=800&q=80',
      type: WardrobeItemType.ethnic,
      isFromOutfitly: true,
      aspectRatio: 0.70,
    ),
    WardrobeItem(
      id: 'w11',
      name: 'Emerald Bandhgala',
      imageUrl:
          'https://images.unsplash.com/photo-1617137968427-85924c800a22?w=800&q=80',
      type: WardrobeItemType.ethnic,
      isFromOutfitly: true,
      aspectRatio: 0.75,
    ),

    // ── Accessories ──
    WardrobeItem(
      id: 'w12',
      name: 'Steel Minimalist Watch',
      imageUrl:
          'https://images.unsplash.com/photo-1524805444758-089113d48a6d?w=800&q=80',
      type: WardrobeItemType.accessory,
      isFromOutfitly: false,
      aspectRatio: 1.0,
    ),
  ];

  List<WardrobeItem> all() => List.unmodifiable(_items);

  List<WardrobeItem> byType(WardrobeItemType type) =>
      _items.where((i) => i.type == type).toList(growable: false);

  WardrobeItem? byId(String id) {
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }
}
