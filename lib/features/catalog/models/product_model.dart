import '../../../core/locale/money.dart';

class ProductModel {
  final String id;
  final String? categoryId;
  final String? categorySlug;
  final String? categoryName;
  final String name;
  final String? description;
  final double basePrice;
  final List<String> images;
  final List<String> fabricOptions;
  final bool isFeatured;
  final String gender; // 'all', 'men', 'women', 'kids'

  const ProductModel({
    required this.id,
    required this.name,
    required this.basePrice,
    this.categoryId,
    this.categorySlug,
    this.categoryName,
    this.description,
    this.images = const [],
    this.fabricOptions = const [],
    this.isFeatured = false,
    this.gender = 'all',
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Support both flat queries and joined queries that nest the
    // category under a `categories` key (Supabase foreign-table join).
    final joined = json['categories'];
    final categorySlug = joined is Map<String, dynamic>
        ? joined['slug'] as String?
        : json['category_slug'] as String?;
    final categoryName = joined is Map<String, dynamic>
        ? joined['name'] as String?
        : json['category_name'] as String?;

    return ProductModel(
      id: json['id'] as String,
      categoryId: json['category_id'] as String?,
      categorySlug: categorySlug,
      categoryName: categoryName,
      name: json['name'] as String,
      description: json['description'] as String?,
      basePrice: (json['base_price'] as num).toDouble(),
      images: List<String>.from(json['images'] ?? []),
      fabricOptions: List<String>.from(json['fabric_options'] ?? []),
      isFeatured: json['is_featured'] as bool? ?? false,
      gender: (json['gender'] as String?) ?? 'all',
    );
  }

  /// Locale-aware price string. Routes through [Money] so UK shoppers
  /// see `£`, JP shoppers see `¥`, etc. — the underlying `basePrice` is
  /// always INR-denominated; conversion happens inside [Money.format].
  String get formattedPrice => Money.formatStatic(basePrice);

  /// True when this product belongs to the Embroidery subcategory.
  /// Matches on slug first (stable), falling back to a case-insensitive
  /// name check for legacy rows where the slug hasn't been populated.
  bool get isEmbroidery {
    final slug = categorySlug?.toLowerCase();
    if (slug != null && slug.contains('embroider')) return true;
    final name = categoryName?.toLowerCase();
    if (name != null && name.contains('embroider')) return true;
    return false;
  }
}
