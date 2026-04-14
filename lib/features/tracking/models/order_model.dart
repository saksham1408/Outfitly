class OrderStatus {
  final String key;
  final String label;
  final String icon;

  const OrderStatus(this.key, this.label, this.icon);

  static const allStatuses = [
    OrderStatus('pending_admin_approval', 'Pending Approval', '⏳'),
    OrderStatus('accepted', 'Order Accepted', '✅'),
    OrderStatus('fabric_sourcing', 'Fabric Sourcing', '🧵'),
    OrderStatus('cutting', 'Cutting', '✂️'),
    OrderStatus('stitching', 'Stitching', '🪡'),
    OrderStatus('embroidery_finishing', 'Embroidery & Finishing', '✨'),
    OrderStatus('quality_check', 'Quality Check', '🔍'),
    OrderStatus('out_for_delivery', 'Out for Delivery', '🚚'),
    OrderStatus('delivered', 'Delivered', '📦'),
  ];

  static int indexOf(String statusKey) {
    return allStatuses.indexWhere((s) => s.key == statusKey);
  }

  static OrderStatus fromKey(String key) {
    return allStatuses.firstWhere(
      (s) => s.key == key,
      orElse: () => allStatuses.first,
    );
  }
}

class OrderModel {
  final String id;
  final String userId;
  final String productName;
  final String? fabric;
  final Map<String, dynamic> designChoices;
  final double totalPrice;
  final String status;
  final DateTime? estimatedDelivery;
  final String? trackingNote;
  final DateTime createdAt;

  const OrderModel({
    required this.id,
    required this.userId,
    required this.productName,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.fabric,
    this.designChoices = const {},
    this.estimatedDelivery,
    this.trackingNote,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      productName: json['product_name'] as String,
      totalPrice: (json['total_price'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      fabric: json['fabric'] as String?,
      designChoices: json['design_choices'] as Map<String, dynamic>? ?? {},
      estimatedDelivery: json['estimated_delivery'] != null
          ? DateTime.tryParse(json['estimated_delivery'] as String)
          : null,
      trackingNote: json['tracking_note'] as String?,
    );
  }

  String get formattedPrice => '₹${totalPrice.toStringAsFixed(0)}';

  int get currentStepIndex => OrderStatus.indexOf(status);

  OrderStatus get currentStatus => OrderStatus.fromKey(status);

  bool get isDelivered => status == 'delivered';

  double get progressPercent =>
      (currentStepIndex + 1) / OrderStatus.allStatuses.length;
}
