import '../../../../core/locale/money.dart';

/// Product linked to a [SubCategory].
class Product {
  final String id;
  final String? subcategoryId; // categories.id
  final String name;
  final String? description;
  final double price;
  final String? mainImageUrl;
  final List<String> images;
  final List<String> fabricOptions;
  final bool isFeatured;
  final String gender;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.subcategoryId,
    this.description,
    this.mainImageUrl,
    this.images = const [],
    this.fabricOptions = const [],
    this.isFeatured = false,
    this.gender = 'all',
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final imagesList = List<String>.from(json['images'] ?? []);
    return Product(
      id: json['id'] as String,
      subcategoryId: json['category_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['base_price'] as num).toDouble(),
      mainImageUrl: imagesList.isNotEmpty ? imagesList.first : null,
      images: imagesList,
      fabricOptions: List<String>.from(json['fabric_options'] ?? []),
      isFeatured: json['is_featured'] as bool? ?? false,
      gender: (json['gender'] as String?) ?? 'all',
    );
  }

  /// Locale-aware price string. See [ProductModel.formattedPrice] for
  /// details — same routing through [Money], same INR-base assumption.
  String get formattedPrice => Money.formatStatic(price);
}
