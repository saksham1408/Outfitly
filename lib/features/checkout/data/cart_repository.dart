import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../../catalog/models/product_model.dart';
import '../models/cart_item.dart';

/// Singleton, ValueNotifier-backed reactive store for the
/// shopping bag.
///
/// Mirrors the pattern every other repository in this app uses
/// (WardrobeRepository, NotificationsRepository,
/// CustomStitchingRepository): one in-memory cache, one
/// `ValueListenable` that the UI watches, one set of mutation
/// methods that update Postgres + the cache atomically.
///
/// This lets the home AppBar's bag badge, the cart screen, and
/// the PDP "Add to Bag" CTA all bind to the same source of truth
/// without dragging in Riverpod / Provider / BLoC.
class CartRepository {
  CartRepository._();
  static final CartRepository instance = CartRepository._();

  static const String _table = 'cart_items';

  final SupabaseClient _client = AppSupabase.client;

  final ValueNotifier<List<CartItem>> _items =
      ValueNotifier<List<CartItem>>(const []);

  /// Live list of items in the bag. Bind to this from the cart
  /// screen + the home badge to stay in sync.
  ValueListenable<List<CartItem>> get items => _items;

  /// Sum of `quantity` across every item. Drives the home AppBar
  /// bag badge.
  ValueListenable<int> get count => _countNotifier;
  late final ValueNotifier<int> _countNotifier =
      ValueNotifier<int>(0)..addListener(() {});

  bool _fetched = false;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;

  /// Idempotent first-load. Called from `main.dart` after Supabase
  /// initialises so the badge has the right number before the
  /// first frame paints.
  Future<void> ensureLoaded() async {
    if (_fetched) return;
    _fetched = true;
    await refresh();
    _attachRealtime();
  }

  /// Force a re-fetch from Postgres. The cart screen pulls this
  /// on mount and on pull-to-refresh.
  Future<void> refresh() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _setItems(const []);
      return;
    }
    try {
      final rows = await _client
          .from(_table)
          .select()
          .order('added_at', ascending: false);
      final list = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(CartItem.fromMap)
          .toList(growable: false);
      _setItems(list);
    } catch (e, st) {
      debugPrint('CartRepository.refresh failed — $e\n$st');
    }
  }

  /// Subscribe to Realtime so a row added on another device
  /// (e.g. the customer used a tablet earlier) shows up here.
  /// RLS scopes the stream to the calling user.
  void _attachRealtime() {
    _realtimeSub?.cancel();
    final user = _client.auth.currentUser;
    if (user == null) return;
    _realtimeSub = _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('added_at', ascending: false)
        .listen((rows) {
          final list =
              rows.map(CartItem.fromMap).toList(growable: false);
          _setItems(list);
        });
  }

  // ── Mutations ────────────────────────────────────────────

  /// Add a product to the bag.
  ///
  /// If the same `(product_id, fabric, size)` combo is already in
  /// the bag, we bump that row's quantity instead of inserting a
  /// duplicate — matches how every consumer e-commerce app
  /// actually behaves. Returns the saved [CartItem].
  Future<CartItem?> addToCart(
    ProductModel product, {
    int quantity = 1,
    String? fabric,
    String? size,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to add items to your bag.');
    }

    // Look for an existing matching row first.
    final existing = _items.value.firstWhere(
      (it) =>
          it.productId == product.id &&
          it.fabric == fabric &&
          it.size == size,
      orElse: () => _none,
    );

    if (!identical(existing, _none)) {
      return updateQuantity(existing.id, existing.quantity + quantity);
    }

    try {
      final inserted = await _client
          .from(_table)
          .insert(CartItem.insertPayload(
            product: product,
            quantity: quantity,
            fabric: fabric,
            size: size,
          ))
          .select()
          .single();
      final saved = CartItem.fromMap(inserted);
      _setItems([saved, ..._items.value]);
      return saved;
    } catch (e, st) {
      debugPrint('CartRepository.addToCart failed — $e\n$st');
      rethrow;
    }
  }

  /// Remove a single line item from the bag.
  Future<void> removeFromCart(String itemId) async {
    try {
      await _client.from(_table).delete().eq('id', itemId);
      _setItems(_items.value.where((it) => it.id != itemId).toList());
    } catch (e, st) {
      debugPrint('CartRepository.removeFromCart failed — $e\n$st');
    }
  }

  /// Adjust the quantity on an existing row. Quantities outside
  /// the 1–99 server CHECK range are clamped here.
  Future<CartItem?> updateQuantity(String itemId, int newQuantity) async {
    final clamped = newQuantity.clamp(1, 99);
    try {
      final updated = await _client
          .from(_table)
          .update({'quantity': clamped})
          .eq('id', itemId)
          .select()
          .single();
      final saved = CartItem.fromMap(updated);
      _setItems(
        _items.value.map((it) => it.id == itemId ? saved : it).toList(),
      );
      return saved;
    } catch (e, st) {
      debugPrint('CartRepository.updateQuantity failed — $e\n$st');
      return null;
    }
  }

  /// Wipe the bag — used after a successful checkout.
  Future<void> clear() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from(_table).delete().eq('user_id', user.id);
      _setItems(const []);
    } catch (e, st) {
      debugPrint('CartRepository.clear failed — $e\n$st');
    }
  }

  // ── Queries ──────────────────────────────────────────────

  /// True if any row references this product (regardless of
  /// fabric/size combo). Used by the PDP CTA to flip "Add to Bag"
  /// → "Go to Bag" when something matching is already saved.
  bool containsProduct(String productId) {
    return _items.value.any((it) => it.productId == productId);
  }

  /// Sum of all quantities — drives the home bag-badge label.
  int getCartCount() {
    return _items.value.fold<int>(0, (sum, it) => sum + it.quantity);
  }

  /// Sum of every line subtotal — used by the bag screen's
  /// summary footer.
  double getCartTotal() {
    return _items.value.fold<double>(0, (sum, it) => sum + it.lineTotal);
  }

  // ── internals ────────────────────────────────────────────

  /// Sentinel used by `firstWhere` to signal "no match" without
  /// throwing. Compared by identity so it can never collide with
  /// a real row's content.
  static final CartItem _none = CartItem(
    id: '',
    userId: '',
    productId: '',
    productName: '',
    productPrice: 0,
    quantity: 0,
    addedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  void _setItems(List<CartItem> list) {
    _items.value = list;
    _countNotifier.value =
        list.fold<int>(0, (sum, it) => sum + it.quantity);
  }
}
