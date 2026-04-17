import '../../../../core/network/supabase_client.dart';
import '../../domain/models/app_category.dart';
import '../../domain/models/product.dart';
import '../../domain/models/sub_category.dart';

/// Single source of truth for catalog data from Supabase.
/// All methods use STRICT filtering — no OR clauses, no gender fallbacks.
/// The DB trigger guarantees products.gender matches category's parent.
class CatalogRepository {
  final _client = AppSupabase.client;

  /// Returns top-level categories (Men, Women, Kids) ordered by sort_order.
  Future<List<AppCategory>> getTopCategories() async {
    final data = await _client
        .from('app_categories')
        .select()
        .order('sort_order');

    return data.map((e) => AppCategory.fromJson(e)).toList();
  }

  /// Returns subcategories for a given top-level [categoryId].
  /// Strict filter: .eq('app_category_id', categoryId)
  Future<List<SubCategory>> getSubCategories(String categoryId) async {
    final data = await _client
        .from('categories')
        .select()
        .eq('app_category_id', categoryId)
        .order('sort_order');

    return data.map((e) => SubCategory.fromJson(e)).toList();
  }

  /// Returns products within a specific [subCategoryId].
  /// STRICT single-filter query — used when user taps a subcategory chip.
  Future<List<Product>> getProductsBySubCategory(String subCategoryId) async {
    final data = await _client
        .from('products')
        .select()
        .eq('category_id', subCategoryId)
        .eq('is_active', true)
        .order('is_featured', ascending: false);

    return data.map((e) => Product.fromJson(e)).toList();
  }

  /// Returns all products for a top-level category (Men/Women/Kids).
  /// Used when "All" chip is active — strict subcategory-IN filter.
  Future<List<Product>> getProductsByTopCategory(String categoryId) async {
    // 1. Collect subcategory IDs that belong to this top category
    final subs = await _client
        .from('categories')
        .select('id')
        .eq('app_category_id', categoryId);

    final subIds = subs.map((s) => s['id'] as String).toList();
    if (subIds.isEmpty) return [];

    // 2. Strict IN filter — no gender OR; the trigger guarantees data integrity
    final data = await _client
        .from('products')
        .select()
        .inFilter('category_id', subIds)
        .eq('is_active', true)
        .order('is_featured', ascending: false);

    return data.map((e) => Product.fromJson(e)).toList();
  }
}
