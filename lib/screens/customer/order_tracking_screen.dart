// lib/screens/customer/order_tracking_screen.dart
import 'package:flutter/material.dart';
import '../../../../models/order_model.dart';
import '../../../../models/user_model.dart';
import '../../services/firestore_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final UserModel user;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.user,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Order'),
      ),
      body: StreamBuilder<OrderModel>(
        stream: _firestoreService.streamOrder(widget.orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Order not found'));
          }

          OrderModel order = snapshot.data!;
          return _buildOrderTracking(order);
        },
      ),
    );
  }

  Widget _buildOrderTracking(OrderModel order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order status card
          Card(
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    _getStatusIcon(order.status),
                    size: 60,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getStatusMessage(order.status),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getStatusDescription(order.status),
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Order progress
          Text(
            'Order Status',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildProgressSteps(order),
          const SizedBox(height: 24),

          // Restaurant info
          Text(
            'Restaurant',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restaurant, color: Colors.orange),
              title: Text(order.restaurantName),
              subtitle: const Text('Preparing your order'),
            ),
          ),

          // Driver info (if assigned)
          if (order.driverId != null) ...[
            const SizedBox(height: 16),
            Text(
              'Delivery Driver',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(order.driverName ?? 'Driver'),
                subtitle: const Text('On the way'),
                trailing: IconButton(
                  icon: const Icon(Icons.phone),
                  onPressed: () {
                    // Call driver functionality
                  },
                ),
              ),
            ),
          ],

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
            child: Column(
              children: order.items.map((item) {
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text('Qty: ${item.quantity}'),
                  trailing: Text(
                    '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Order summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSummaryRow('Subtotal', order.subtotal),
                  _buildSummaryRow('Delivery Fee', order.deliveryFee),
                  _buildSummaryRow('Tax', order.tax),
                  const Divider(),
                  _buildSummaryRow('Total', order.total, isBold: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSteps(OrderModel order) {
    List<OrderStatus> steps = [
      OrderStatus.pending,
      OrderStatus.accepted,
      OrderStatus.preparing,
      OrderStatus.ready_for_pickup,
      OrderStatus.out_for_delivery,
      OrderStatus.delivered,
    ];

    int currentIndex = steps.indexOf(order.status);

    return Column(
      children: steps.asMap().entries.map((entry) {
        int index = entry.key;
        OrderStatus status = entry.value;
        bool isCompleted = index <= currentIndex;
        bool isCurrent = index == currentIndex;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step indicator
            Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted ? Colors.orange : Colors.grey[300],
                  ),
                  child: Icon(
                    isCompleted ? Icons.check : Icons.circle,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 2,
                    height: 40,
                    color: isCompleted ? Colors.orange : Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Step details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getStepTitle(status),
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCompleted ? Colors.black : Colors.grey,
                    ),
                  ),
                  if (index < steps.length - 1) const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        );
      }).toList(),
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

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.access_time;
      case OrderStatus.accepted:
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready_for_pickup:
      case OrderStatus.driver_assigned:
        return Icons.shopping_bag;
      case OrderStatus.out_for_delivery:
      case OrderStatus.arriving:
        return Icons.delivery_dining;
      case OrderStatus.delivered:
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  String _getStatusMessage(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Order Placed!';
      case OrderStatus.accepted:
        return 'Order Accepted';
      case OrderStatus.preparing:
        return 'Preparing Your Food';
      case OrderStatus.ready_for_pickup:
        return 'Ready for Pickup';
      case OrderStatus.driver_assigned:
      case OrderStatus.driver_at_restaurant:
        return 'Driver on the Way';
      case OrderStatus.out_for_delivery:
        return 'Out for Delivery';
      case OrderStatus.arriving:
        return 'Driver is Nearby';
      case OrderStatus.delivered:
        return 'Delivered!';
      default:
        return 'Processing Order';
    }
  }

  String _getStatusDescription(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Waiting for restaurant confirmation';
      case OrderStatus.accepted:
        return 'Your order has been accepted';
      case OrderStatus.preparing:
        return 'The restaurant is preparing your food';
      case OrderStatus.ready_for_pickup:
        return 'Your order is ready';
      case OrderStatus.driver_assigned:
        return 'A driver has been assigned';
      case OrderStatus.out_for_delivery:
        return 'Your order is on its way';
      case OrderStatus.delivered:
        return 'Enjoy your meal!';
      default:
        return '';
    }
  }

  String _getStepTitle(OrderStatus status) {
    return status.toString().split('.').last.replaceAll('_', ' ').toUpperCase();
  }
}