import 'package:flutter/foundation.dart';

import '../../catalog/models/product_model.dart';

/// One row from `public.cart_items` — a saved-but-not-yet-bought
/// product in the user's shopping bag.
///
/// The denormalised product fields (name, image, price) are
/// snapshots of the catalog row at add-time. Storing them lets
/// the bag render instantly without a join, *and* lock the
/// customer's price even if the catalog rate changes between
/// adding and checkout — the standard e-commerce contract.
@immutable
class CartItem {
  const CartItem({
    required this.id,
    required this.userId,
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    required this.addedAt,
    this.productImage,
    this.fabric,
    this.size,
  });

  final String id;
  final String userId;
  final String productId;
  final String productName;
  final String? productImage;
  final double productPrice;
  final int quantity;
  final String? fabric;
  final String? size;
  final DateTime addedAt;

  /// Line-item subtotal: `productPrice × quantity`.
  double get lineTotal => productPrice * quantity;

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      productId: map['product_id'] as String,
      productName: (map['product_name'] as String?)?.trim() ?? 'Item',
      productImage:
          (map['product_image'] as String?)?.trim().isEmpty ?? true
              ? null
              : (map['product_image'] as String).trim(),
      productPrice: (map['product_price'] as num).toDouble(),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      fabric: (map['fabric'] as String?)?.trim().isEmpty ?? true
          ? null
          : (map['fabric'] as String).trim(),
      size: (map['size'] as String?)?.trim().isEmpty ?? true
          ? null
          : (map['size'] as String).trim(),
      addedAt:
          DateTime.tryParse(map['added_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  /// Build the INSERT payload from a [ProductModel] + optional
  /// customisation. `id`, `user_id`, `added_at` are server-filled
  /// (gen_random_uuid + auth.uid + DEFAULT now()).
  static Map<String, dynamic> insertPayload({
    required ProductModel product,
    int quantity = 1,
    String? fabric,
    String? size,
  }) {
    return <String, dynamic>{
      'product_id': product.id,
      'product_name': product.name,
      'product_image': product.images.isNotEmpty ? product.images.first : null,
      'product_price': product.basePrice,
      'quantity': quantity,
      if (fabric != null) 'fabric': fabric,
      if (size != null) 'size': size,
    };
  }
}
