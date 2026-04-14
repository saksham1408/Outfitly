import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lookbook_item_model.dart';

/// Fetches lookbook items from Directus CMS.
/// Admin panel: http://localhost:8055
class LookbookService {
  // When running on iOS simulator, localhost maps to the Mac host.
  static const _baseUrl = 'http://localhost:8055';

  Future<List<LookbookItemModel>> getAllItems() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/items/lookbook_items'),
    );

    if (response.statusCode != 200) return [];

    final json = jsonDecode(response.body);
    final List items = json['data'] ?? [];
    return items.map((e) => LookbookItemModel.fromJson(e)).toList();
  }

  Future<List<LookbookItemModel>> getItemsByCategory(String category) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/items/lookbook_items?filter[category][_eq]=$category',
      ),
    );

    if (response.statusCode != 200) return [];

    final json = jsonDecode(response.body);
    final List items = json['data'] ?? [];
    return items.map((e) => LookbookItemModel.fromJson(e)).toList();
  }

  Future<LookbookItemModel?> getItem(String id) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/items/lookbook_items/$id'),
    );

    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body);
    return json['data'] != null
        ? LookbookItemModel.fromJson(json['data'])
        : null;
  }

  Future<List<String>> getCategories() async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/items/lookbook_items?fields=category',
      ),
    );

    if (response.statusCode != 200) {
      // Fallback: get all items and extract categories
      final items = await getAllItems();
      return items.map((e) => e.category).whereType<String>().toSet().toList();
    }

    final json = jsonDecode(response.body);
    final List items = json['data'] ?? [];
    return items
        .map((e) => e['category'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
  }
}
