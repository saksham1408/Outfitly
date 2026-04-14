import '../../../core/network/supabase_client.dart';

class WishlistService {
  final _client = AppSupabase.client;

  Future<List<Map<String, dynamic>>> getWishlist() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    return await _client
        .from('wishlist')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
  }

  Future<bool> isInWishlist(String itemId, String itemType) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final data = await _client
        .from('wishlist')
        .select('id')
        .eq('user_id', user.id)
        .eq('item_id', itemId)
        .eq('item_type', itemType)
        .maybeSingle();

    return data != null;
  }

  Future<void> addToWishlist(String itemId, String itemType) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('wishlist').upsert({
      'user_id': user.id,
      'item_id': itemId,
      'item_type': itemType,
    });
  }

  Future<void> removeFromWishlist(String itemId, String itemType) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from('wishlist')
        .delete()
        .eq('user_id', user.id)
        .eq('item_id', itemId)
        .eq('item_type', itemType);
  }

  Future<void> toggleWishlist(String itemId, String itemType) async {
    final inList = await isInWishlist(itemId, itemType);
    if (inList) {
      await removeFromWishlist(itemId, itemType);
    } else {
      await addToWishlist(itemId, itemType);
    }
  }
}
