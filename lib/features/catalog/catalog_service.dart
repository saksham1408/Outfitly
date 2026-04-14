import '../../core/network/supabase_client.dart';
import 'models/category_model.dart';
import 'models/product_model.dart';

class CatalogService {
  final _client = AppSupabase.client;

  Future<List<CategoryModel>> getCategories() async {
    final data = await _client
        .from('categories')
        .select()
        .order('sort_order');

    return data.map((e) => CategoryModel.fromJson(e)).toList();
  }

  Future<List<ProductModel>> getFeaturedProducts() async {
    final data = await _client
        .from('products')
        .select()
        .eq('is_featured', true)
        .order('created_at', ascending: false);

    return data.map((e) => ProductModel.fromJson(e)).toList();
  }

  Future<List<ProductModel>> getProductsByCategory(String categoryId) async {
    final data = await _client
        .from('products')
        .select()
        .eq('category_id', categoryId)
        .order('created_at', ascending: false);

    return data.map((e) => ProductModel.fromJson(e)).toList();
  }

  Future<ProductModel?> getProduct(String id) async {
    final data = await _client
        .from('products')
        .select()
        .eq('id', id)
        .maybeSingle();

    return data != null ? ProductModel.fromJson(data) : null;
  }
}
