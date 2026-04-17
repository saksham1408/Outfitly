class ProductModel {
  final String id;
  final String? categoryId;
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
    this.description,
    this.images = const [],
    this.fabricOptions = const [],
    this.isFeatured = false,
    this.gender = 'all',
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      categoryId: json['category_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      basePrice: (json['base_price'] as num).toDouble(),
      images: List<String>.from(json['images'] ?? []),
      fabricOptions: List<String>.from(json['fabric_options'] ?? []),
      isFeatured: json['is_featured'] as bool? ?? false,
      gender: (json['gender'] as String?) ?? 'all',
    );
  }

  String get formattedPrice => '\u20B9${basePrice.toStringAsFixed(0)}';
}
