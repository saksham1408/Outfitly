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

  Future<List<ProductModel>> getAllProducts() async {
    final data = await _client
        .from('products')
        .select()
        .eq('is_active', true)
        .order('is_featured', ascending: false);

    return data.map((e) => ProductModel.fromJson(e)).toList();
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
    // Join the parent category so the PDP can route Embroidery products
    // through the Design Studio (which shows the custom upload step).
    final data = await _client
        .from('products')
        .select('*, categories(slug, name)')
        .eq('id', id)
        .maybeSingle();

    return data != null ? ProductModel.fromJson(data) : null;
  }
}
