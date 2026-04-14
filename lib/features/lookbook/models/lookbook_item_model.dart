class LookbookItemModel {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? fabricType;
  final String? imageUrl;
  final List<String> colors;
  final String? category;
  final int sortOrder;

  const LookbookItemModel({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.fabricType,
    this.imageUrl,
    this.colors = const [],
    this.category,
    this.sortOrder = 0,
  });

  factory LookbookItemModel.fromJson(Map<String, dynamic> json) {
    return LookbookItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      fabricType: json['fabric_type'] as String?,
      imageUrl: json['image_url'] as String?,
      colors: List<String>.from(json['colors'] ?? []),
      category: json['category'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  String get formattedPrice => '\u20B9${price.toStringAsFixed(0)}';
}
