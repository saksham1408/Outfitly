import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../widgets/tracking_timeline.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _orderService = OrderService();
  OrderModel? _order;
  bool _loading = true;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final order = await _orderService.getOrder(widget.orderId);
    if (!mounted) return;
    setState(() {
      _order = order;
      _loading = false;
    });

    // Subscribe to realtime updates
    if (order != null) {
      _subscription = _orderService.subscribeToOrder(
        widget.orderId,
        (updated) {
          if (mounted) setState(() => _order = updated);
        },
      );
    }
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final order = _order;
    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Order not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Track Order',
          style: GoogleFonts.newsreader(
            fontSize: 22,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Order Info Card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order.productName,
                        style: GoogleFonts.newsreader(
                          fontSize: 22,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        order.formattedPrice,
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentContainer,
                        ),
                      ),
                    ],
                  ),
                  if (order.fabric != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      order.fabric!,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: Colors.white.withAlpha(180),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Progress
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: order.progressPercent,
                      minHeight: 6,
                      backgroundColor: Colors.white.withAlpha(30),
                      valueColor: AlwaysStoppedAnimation(AppColors.accentContainer),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(order.progressPercent * 100).toInt()}% complete',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: Colors.white.withAlpha(180),
                        ),
                      ),
                      if (order.estimatedDelivery != null)
                        Text(
                          'Est. ${_formatDate(order.estimatedDelivery!)}',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: AppColors.accentContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Tracking Note ──
            if (order.trackingNote != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withAlpha(40)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        order.trackingNote!,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: AppColors.accent,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // ── Timeline Header ──
            Text(
              'ORDER TIMELINE',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 20),

            // ── Timeline ──
            TrackingTimeline(currentStep: order.currentStepIndex),

            const SizedBox(height: 32),

            // ── Order Details ──
            Text(
              'ORDER DETAILS',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _detailRow('Order ID', order.id.substring(0, 8).toUpperCase()),
                  const Divider(height: 20),
                  _detailRow('Product', order.productName),
                  if (order.fabric != null) ...[
                    const Divider(height: 20),
                    _detailRow('Fabric', order.fabric!),
                  ],
                  const Divider(height: 20),
                  _detailRow('Total', order.formattedPrice),
                  const Divider(height: 20),
                  _detailRow('Ordered', _formatDate(order.createdAt)),
                  if (order.estimatedDelivery != null) ...[
                    const Divider(height: 20),
                    _detailRow('Est. Delivery', _formatDate(order.estimatedDelivery!)),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 13, color: AppColors.textTertiary),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
