import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../models/order_model.dart';

class OrderService {
  final _client = AppSupabase.client;

  Future<List<OrderModel>> getOrders() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final data = await _client
        .from('orders')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return data.map((e) => OrderModel.fromJson(e)).toList();
  }

  Future<OrderModel?> getOrder(String id) async {
    final data = await _client
        .from('orders')
        .select()
        .eq('id', id)
        .maybeSingle();

    return data != null ? OrderModel.fromJson(data) : null;
  }

  /// Listen for realtime status changes on a specific order.
  RealtimeChannel subscribeToOrder(
    String orderId,
    void Function(OrderModel order) onUpdate,
  ) {
    return _client
        .channel('order-$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: orderId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            onUpdate(OrderModel.fromJson(data));
          },
        )
        .subscribe();
  }

  /// Create a demo order for testing.
  Future<OrderModel?> createDemoOrder() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final data = await _client.from('orders').insert({
      'user_id': user.id,
      'product_name': 'Classic Oxford Shirt',
      'fabric': 'Supima Cotton',
      'total_price': 2999,
      'status': 'stitching',
      'estimated_delivery':
          DateTime.now().add(const Duration(days: 10)).toIso8601String().split('T')[0],
      'tracking_note': 'Your shirt is being stitched by master tailor Ramesh.',
    }).select().single();

    return OrderModel.fromJson(data);
  }
}
