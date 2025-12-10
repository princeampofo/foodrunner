// lib/screens/restaurant/order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/order_model.dart';
import '../../services/firestore_service.dart';
import '../../services/driver_assignment_service.dart';

final DriverAssignmentService _driverAssignmentService = DriverAssignmentService();

class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late OrderModel _order;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _listenToOrderUpdates();
  }

  void _listenToOrderUpdates() {
    _firestoreService.streamOrder(_order.id).listen((updatedOrder) {
      if (mounted) {
        setState(() {
          _order = updatedOrder;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${_order.id.substring(0, 8)}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live Status Card with Animation
            _buildLiveStatusCard(),
            const SizedBox(height: 24),

            // Customer info
            Text(
              'Customer Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.person, 'Name', _order.customerName),
                    const Divider(height: 20),
                    _buildInfoRow(Icons.phone, 'Phone', _order.customerPhone),
                    const Divider(height: 20),
                    _buildInfoRow(
                      Icons.location_on,
                      'Address',
                      _order.deliveryAddress,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Order items
            Text(
              'Order Items',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ..._order.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${item.quantity}x',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (item.specialInstructions != null)
                                      Text(
                                        item.specialInstructions!,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )),
                    const Divider(),
                    _buildSummaryRow('Subtotal', _order.subtotal),
                    _buildSummaryRow('Delivery Fee', _order.deliveryFee),
                    _buildSummaryRow('Tax', _order.tax),
                    const Divider(),
                    _buildSummaryRow('Total', _order.total, isBold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Driver info (if assigned)
            if (_order.driverId != null) ...[
              Text(
                'Driver Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.delivery_dining),
                  ),
                  title: Text(_order.driverName ?? 'Driver'),
                  subtitle: Text(_order.getStatusMessage()),
                  trailing: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatusCard() {
    final bool isSearchingDriver = _order.status == OrderStatus.finding_driver;
    final bool noDriverAvailable = _order.status == OrderStatus.no_driver_available;
    final bool driverAssigned = _order.driverId != null;

    return Card(
      elevation: 4,
      color: _order.getStatusColor().withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Animated icon for searching
                if (isSearchingDriver)
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: _order.getStatusColor(),
                      strokeWidth: 3,
                    ),
                  )
                else
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _order.getStatusColor(),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _order.getStatusIcon(),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusTitle(_order.status),
                        style: TextStyle(
                          color: _order.getStatusColor(),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _order.getStatusMessage(),
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Show additional info based on status
            if (isSearchingDriver) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Broadcasting to nearby drivers...',
                        style: TextStyle(
                          color: Colors.amber[900],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (noDriverAvailable) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No drivers accepted yet',
                            style: TextStyle(
                              color: Colors.red[900],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _retryBroadcast,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry Finding Driver'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (driverAssigned) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_order.driverName} is handling this order',
                        style: TextStyle(
                          color: Colors.green[900],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Add retry broadcast method:
  Future<void> _retryBroadcast() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Retrying to find drivers...'),
          backgroundColor: Colors.orange,
        ),
      );

      await _driverAssignmentService.broadcastOrderToNearbyDrivers(_order);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Broadcast sent again!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Add helper for status titles:
  String _getStatusTitle(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'New Order';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready_for_pickup:
        return 'Ready';
      case OrderStatus.finding_driver:
        return 'Finding Driver';
      case OrderStatus.no_driver_available:
        return 'No Driver Available';
      case OrderStatus.driver_assigned:
        return 'Driver Assigned';
      case OrderStatus.driver_at_restaurant:
        return 'Driver Arrived';
      case OrderStatus.out_for_delivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Processing';
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    switch (_order.status) {
      case OrderStatus.pending:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _acceptOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Accept Order'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _rejectOrder,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Reject'),
              ),
            ),
          ],
        );

      case OrderStatus.accepted:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _markAsPreparing,
            child: const Text('Start Preparing'),
          ),
        );

      case OrderStatus.preparing:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _markAsReady,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Mark as Ready for Pickup'),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _acceptOrder() async {
    try {
      await _firestoreService.updateOrderStatus(_order.id, OrderStatus.accepted);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order accepted!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _rejectOrder() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Order'),
        content: const Text('Are you sure you want to reject this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.updateOrderStatus(_order.id, OrderStatus.cancelled);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order rejected')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _markAsPreparing() async {
    try {
      await _firestoreService.updateOrderStatus(_order.id, OrderStatus.preparing);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order marked as preparing')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _markAsReady() async {
    try {
      // Step 1: Mark order as ready for pickup
      await _firestoreService.updateOrderStatus(
          _order.id, OrderStatus.ready_for_pickup);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order ready! Finding nearby drivers...'),
          backgroundColor: Colors.orange,
        ),
      );

      // Step 2: Wait a moment for status to update
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 3: Reload order with updated status
      OrderModel? updatedOrder = await _firestoreService.getOrder(_order.id);
      
      if (updatedOrder == null) {
        throw Exception('Failed to reload order');
      }

      // Step 4: Broadcast to nearby drivers
      await _driverAssignmentService.broadcastOrderToNearbyDrivers(updatedOrder);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order broadcast to nearby drivers!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
     debugPrint('Error in _markAsReady: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.accepted:
      case OrderStatus.preparing:
        return Colors.blue;
      case OrderStatus.ready_for_pickup:
        return Colors.purple;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.access_time;
      case OrderStatus.accepted:
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready_for_pickup:
        return Icons.done_all;
      case OrderStatus.delivered:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending Acceptance';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready_for_pickup:
        return 'Ready for Pickup';
      case OrderStatus.driver_assigned:
        return 'Driver Assigned';
      case OrderStatus.out_for_delivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Processing';
    }
  }
}