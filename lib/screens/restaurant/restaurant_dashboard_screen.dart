// lib/screens/restaurant/restaurant_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/order_model.dart';
import '../../services/firestore_service.dart';
import 'order_detail_screen.dart';
import 'menu_management_screen.dart';
import '../shared/profile_screen.dart';

class RestaurantDashboardScreen extends StatefulWidget {
  final UserModel user;

  const RestaurantDashboardScreen({super.key, required this.user});

  @override
  State<RestaurantDashboardScreen> createState() =>
      _RestaurantDashboardScreenState();
}

class _RestaurantDashboardScreenState extends State<RestaurantDashboardScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MenuManagementScreen(restaurantId: widget.user.id),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(user: widget.user),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'New Orders'),
            Tab(text: 'Preparing'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // New Orders Tab (pending status)
          _buildOrdersList([OrderStatus.pending]),
          
          // Preparing Tab (accepted, preparing)
          _buildOrdersList([
            OrderStatus.accepted,
            OrderStatus.preparing,
          ]),
          
          // Completed Tab (ready, delivered, cancelled)
          _buildOrdersList([
            OrderStatus.ready_for_pickup,
            OrderStatus.finding_driver,
            OrderStatus.no_driver_available,
            OrderStatus.driver_assigned,
            OrderStatus.driver_at_restaurant,
            OrderStatus.out_for_delivery,
            OrderStatus.arriving,
            OrderStatus.delivered,
            OrderStatus.cancelled,
          ]),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<OrderStatus> statuses) {
    return StreamBuilder<List<OrderModel>>(
      stream: _firestoreService.getRestaurantOrders(widget.user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No orders',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Filter orders by status
        List<OrderModel> filteredOrders = snapshot.data!
            .where((order) => statuses.contains(order.status))
            .toList();

        // Sort by creation time (newest first)
        filteredOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (filteredOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _getEmptyMessage(statuses),
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredOrders.length,
          itemBuilder: (context, index) {
            OrderModel order = filteredOrders[index];
            bool isNew = statuses.contains(OrderStatus.pending);
            return _buildOrderCard(order, isNew: isNew);
          },
        );
      },
    );
  }

  String _getEmptyMessage(List<OrderStatus> statuses) {
    if (statuses.contains(OrderStatus.pending)) {
      return 'No new orders';
    } else if (statuses.contains(OrderStatus.accepted)) {
      return 'No orders being prepared';
    } else {
      return 'No completed orders';
    }
  }

  Widget _buildOrderCard(OrderModel order, {bool isNew = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isNew ? 4 : 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailScreen(order: order),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Order #${order.id.substring(0, 8)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status badge
                      _buildStatusBadge(order.status),
                    ],
                  ),
                  if (isNew)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Customer info
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    order.customerName,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    order.customerPhone,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              // Time
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, hh:mm a').format(order.createdAt),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),

              // Driver info if assigned
              if (order.driverId != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.delivery_dining,
                          size: 16, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Driver: ${order.driverName}',
                        style: TextStyle(
                          color: Colors.green[900],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 20),
              
              // Order items
              ...order.items.take(3).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity}x ${item.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  )),
              if (order.items.length > 3)
                Text(
                  '+ ${order.items.length - 3} more items',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              
              const Divider(height: 20),
              
              // Total and actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: \$${order.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (isNew)
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => _acceptOrder(order),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                          child: const Text('Accept'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _rejectOrder(order),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                          child: const Text('Reject'),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color backgroundColor;
    Color textColor;
    String text;
    IconData icon;

    switch (status) {
      case OrderStatus.pending:
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[900]!;
        text = 'Pending';
        icon = Icons.access_time;
        break;
      case OrderStatus.accepted:
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[900]!;
        text = 'Accepted';
        icon = Icons.check;
        break;
      case OrderStatus.preparing:
        backgroundColor = Colors.purple[100]!;
        textColor = Colors.purple[900]!;
        text = 'Preparing';
        icon = Icons.restaurant;
        break;
      case OrderStatus.ready_for_pickup:
        backgroundColor = Colors.teal[100]!;
        textColor = Colors.teal[900]!;
        text = 'Ready';
        icon = Icons.done_all;
        break;
      case OrderStatus.finding_driver:
        backgroundColor = Colors.amber[100]!;
        textColor = Colors.amber[900]!;
        text = 'Finding Driver';
        icon = Icons.search;
        break;
      case OrderStatus.no_driver_available:
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[900]!;
        text = 'No Driver';
        icon = Icons.warning;
        break;
      case OrderStatus.driver_assigned:
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        text = 'Driver Assigned';
        icon = Icons.person;
        break;
      case OrderStatus.driver_at_restaurant:
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        text = 'Driver Here';
        icon = Icons.place;
        break;
      case OrderStatus.out_for_delivery:
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        text = 'Out for Delivery';
        icon = Icons.delivery_dining;
        break;
      case OrderStatus.arriving:
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        text = 'Arriving';
        icon = Icons.near_me;
        break;
      case OrderStatus.delivered:
        backgroundColor = Colors.green[200]!;
        textColor = Colors.green[900]!;
        text = 'Delivered';
        icon = Icons.check_circle;
        break;
      case OrderStatus.cancelled:
        backgroundColor = Colors.grey[300]!;
        textColor = Colors.grey[800]!;
        text = 'Cancelled';
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptOrder(OrderModel order) async {
    try {
      await _firestoreService.updateOrderStatus(
          order.id, OrderStatus.accepted);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order accepted!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _rejectOrder(OrderModel order) async {
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.updateOrderStatus(
            order.id, OrderStatus.cancelled);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order rejected'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}