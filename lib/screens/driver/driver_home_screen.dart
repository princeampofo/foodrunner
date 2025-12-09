// lib/screens/driver/driver_home_screen.dart
import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
import '../../../../models/user_model.dart';
import '../../../../models/driver_model.dart';
import '../../../../models/order_model.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
// import '../../services/auth_service.dart';
import 'active_delivery_screen.dart';
import 'driver_earnings_screen.dart';
import '../../../../screens/shared/profile_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  final UserModel user;

  const DriverHomeScreen({super.key, required this.user});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  bool _isOnline = false;
  DriverModel? _driverData;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    DriverModel? driver = await _firestoreService.getDriver(widget.user.id);
    if (mounted) {
      setState(() {
        _driverData = driver;
        _isOnline = driver?.isOnline ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_money),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DriverEarningsScreen(driverId: widget.user.id),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
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
      ),
      body: _driverData == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Online/Offline toggle
                Container(
                  padding: const EdgeInsets.all(24),
                  color: _isOnline ? Colors.green[50] : Colors.grey[200],
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isOnline ? Icons.check_circle : Icons.cancel,
                            size: 40,
                            color: _isOnline ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isOnline ? "You're Online" : "You're Offline",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _isOnline ? Colors.green : Colors.grey[700],
                                ),
                              ),
                              Text(
                                _isOnline
                                    ? 'Ready to accept orders'
                                    : 'Go online to start accepting orders',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _toggleOnlineStatus(!_isOnline),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isOnline ? Colors.red : Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            _isOnline ? 'Go Offline' : 'Go Online',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Today's stats
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Deliveries',
                          _driverData!.totalDeliveries.toString(),
                          Icons.delivery_dining,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Today',
                          '\$${_driverData!.todayEarnings.toStringAsFixed(2)}',
                          Icons.attach_money,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Rating',
                          _driverData!.rating.toStringAsFixed(1),
                          Icons.star,
                          Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),

                // Active orders
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Orders',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (_driverData!.activeOrderIds.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_driverData!.activeOrderIds.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Active orders list
                Expanded(
                  child: StreamBuilder<List<OrderModel>>(
                    stream: _firestoreService.getDriverOrders(widget.user.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isOnline
                                    ? 'Waiting for orders...'
                                    : 'Go online to see orders',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          OrderModel order = snapshot.data![index];
                          return _buildOrderCard(order);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ActiveDeliveryScreen(
                order: order,
                driver: _driverData!,
              ),
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
                  Text(
                    'Order #${order.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  _buildOrderStatusChip(order.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.restaurant, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(order.restaurantName)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.deliveryAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.items.length} items',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    'Earn: \$${(order.deliveryFee * 0.8).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderStatusChip(OrderStatus status) {
    String text;
    Color color;

    switch (status) {
      case OrderStatus.driver_assigned:
      case OrderStatus.driver_at_restaurant:
        text = 'Pickup';
        color = Colors.blue;
        break;
      case OrderStatus.out_for_delivery:
      case OrderStatus.arriving:
        text = 'Delivering';
        color = Colors.orange;
        break;
      default:
        text = 'Active';
        color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _toggleOnlineStatus(bool goOnline) async {
    if (goOnline) {
      // Request location permission
      bool hasPermission = await _locationService.requestPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to go online'),
          ),
        );
        return;
      }

      // Start location tracking
      _locationService.startTracking(
        driverId: widget.user.id,
        hasActiveDelivery: false,
      );
    } else {
      // Stop location tracking
      _locationService.stopTracking();
    }

    try {
      await _firestoreService.updateDriverOnlineStatus(widget.user.id, goOnline);
      setState(() => _isOnline = goOnline);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(goOnline ? 'You are now online!' : 'You are now offline'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}