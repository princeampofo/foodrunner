// lib/screens/driver/driver_home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../models/user_model.dart';
import '../../models/driver_model.dart';
import '../../models/order_model.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import 'active_delivery_screen.dart';
import 'driver_earnings_screen.dart';
import 'order_request_modal.dart';
import '../shared/profile_screen.dart';

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
  
  // Subscriptions
  StreamSubscription? _orderRequestSubscription;
  StreamSubscription<DriverModel>? _driverDataSubscription;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  @override
  void dispose() {
    debugPrint('🗑️ Disposing driver home screen');
    _orderRequestSubscription?.cancel();
    _driverDataSubscription?.cancel();
    
    // Stop location tracking if online
    if (_isOnline) {
      _locationService.stopTracking();
    }
    
    super.dispose();
  }

  Future<void> _loadDriverData() async {
    try {
      debugPrint('📊 Loading driver data for: ${widget.user.id}');
      
      DriverModel? driver = await _firestoreService.getDriver(widget.user.id);
      
      if (mounted) {
        setState(() {
          _driverData = driver;
          _isOnline = driver?.isOnline ?? false;
        });
        
        debugPrint('✅ Driver data loaded: ${driver?.name}');
        debugPrint('   Online: $_isOnline');
        debugPrint('   Available: ${driver?.isAvailable}');
        
        // Start listening for order requests if online
        if (_isOnline) {
          _listenForOrderRequests();
        }
        
        // Listen to driver data changes
        _listenToDriverData();
      }
    } catch (e) {
      debugPrint('❌ Error loading driver data: $e');
    }
  }

  // Listen to real-time driver data updates
  void _listenToDriverData() {
    debugPrint('👂 Listening to driver data updates');
    
    _driverDataSubscription = _firestoreService.streamDriver(widget.user.id).listen(
      (driver) {
        if (mounted) {
          setState(() {
            _driverData = driver;
          });
        }
      },
      onError: (error) {
        debugPrint('❌ Error in driver data stream: $error');
      },
    );
  }

  // Listen for order requests
  void _listenForOrderRequests() {
    debugPrint('👂 Listening for order requests for driver: ${widget.user.id}');
    
    // Cancel existing subscription
    _orderRequestSubscription?.cancel();
    
    // Listen for new order requests
    _orderRequestSubscription = FirebaseFirestore.instance
        .collection('orderRequests')
        .where('driverId', isEqualTo: widget.user.id)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        debugPrint('📬 Order requests snapshot received: ${snapshot.docs.length} docs');
        
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            debugPrint('🆕 New order request detected!');
            debugPrint('   Request ID: ${change.doc.id}');
            
            Map<String, dynamic> requestData = change.doc.data() as Map<String, dynamic>;
            debugPrint('   Order ID: ${requestData['orderId']}');
            debugPrint('   Restaurant: ${requestData['restaurantName']}');
            
            // Show order request modal
            _showOrderRequestModal(change.doc.id, requestData);
          }
        }
      },
      onError: (error) {
        debugPrint('❌ Error in order requests stream: $error');
      },
    );
    
    debugPrint('✅ Order request listener started');
  }

  void _showOrderRequestModal(String requestId, Map<String, dynamic> requestData) {
    debugPrint('🔔 Showing order request modal');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => OrderRequestModal(
        driverId: widget.user.id,
        requestData: requestData,
        requestId: requestId,
      ),
    ).then((accepted) {
      debugPrint('📋 Order request dialog closed. Accepted: $accepted');
      
      if (accepted == true) {
        // Reload driver data to reflect new order
        _loadDriverData();
      }
    });
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

                // Active orders header
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
                              if (_isOnline) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Orders will appear here when restaurants are ready',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
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
    debugPrint('🔄 Toggling online status: $goOnline');
    
    if (goOnline) {
      // Going online - need location permission
      debugPrint('📍 Requesting location permission...');
      
      bool hasPermission = await _locationService.requestPermission();
      if (!hasPermission) {
        debugPrint('❌ Location permission denied');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to go online'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      debugPrint('✅ Location permission granted');
      
      // Get initial location
      debugPrint('📍 Getting initial location...');
      var position = await _locationService.getCurrentLocation();
      
      if (position == null) {
        debugPrint('❌ Could not get location');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get your location. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      debugPrint('✅ Initial location: ${position.latitude}, ${position.longitude}');
      
      // Start location tracking
      debugPrint('🚗 Starting location tracking...');
      _locationService.startTracking(
        driverId: widget.user.id,
        hasActiveDelivery: false,
      );
      
      // Start listening for order requests
      debugPrint('👂 Starting order request listener...');
      _listenForOrderRequests();
      
    } else {
      // Going offline
      debugPrint('🛑 Going offline...');
      
      // Stop location tracking
      _locationService.stopTracking();
      
      // Stop listening for order requests
      _orderRequestSubscription?.cancel();
      _orderRequestSubscription = null;
      
      debugPrint('✅ Stopped tracking and listening');
    }

    try {
      // Update driver status in Firestore
      debugPrint('💾 Updating Firestore...');
      await _firestoreService.updateDriverOnlineStatus(widget.user.id, goOnline);
      
      setState(() => _isOnline = goOnline);
      
      debugPrint('✅ Driver status updated in Firestore');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(goOnline 
              ? 'You are now online! Waiting for orders...' 
              : 'You are now offline'),
            backgroundColor: goOnline ? Colors.green : Colors.grey,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error updating driver status: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
