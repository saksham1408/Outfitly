/// Top-level category: Men / Women / Kids.
class AppCategory {
  final String id;
  final String name;
  final int sortOrder;

  const AppCategory({
    required this.id,
    required this.name,
    this.sortOrder = 0,
  });

  factory AppCategory.fromJson(Map<String, dynamic> json) {
    return AppCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}
