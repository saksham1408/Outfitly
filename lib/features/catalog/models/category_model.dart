class CategoryModel {
  final String id;
  final String name;
  final String slug;
  final String? imageUrl;
  final int sortOrder;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.sortOrder = 0,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      imageUrl: json['image_url'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}
