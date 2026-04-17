/// Subcategory linked to an [AppCategory] (e.g. Ethnics → Men).
class SubCategory {
  final String id;
  final String? categoryId; // app_category_id
  final String name;
  final String slug;
  final String? imageUrl;
  final int sortOrder;

  const SubCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.categoryId,
    this.imageUrl,
    this.sortOrder = 0,
  });

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      id: json['id'] as String,
      categoryId: json['app_category_id'] as String?,
      name: json['name'] as String,
      slug: json['slug'] as String,
      imageUrl: json['image_url'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}
